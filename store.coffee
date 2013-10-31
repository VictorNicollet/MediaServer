require 'coffee-script'
crypto = require 'crypto'
MutexHash = require './mutex-hash'

# It is forbidden to run simultaneous updates on the same document
# (since this would lead to one update being ignored by the other)
# A mutex hash is used to sequentialize updates.
#
# `safeUpdate params, action, next` runs `action next`, but makes
# sure only one action runs for the S3 object identified by
# `params` at a time.

withLock = do ->
  mutex = new MutexHash()
  keyOfParams = (params) -> params.Bucket + '/' + params.Key
  (params, next, action) ->
    mutex.run keyOfParams(params), next, action

# A store is a wrapper against a naive storage database.
#
# A storage database MUST implement the following methods:
#
#  - `uid(path)` returns an unique identifier for the object
#    at the specified path. Must be unique across all database
#    models, though only within a process.
# 
#  - `put(path,obj,next)`: puts the object `obj` at
#    `path`, calls `next(err)` afterwards. `obj` should contain
#    field `body`, and may contain fields `contentType` and
#    `contentDisposition`.
#
#  - `get(path,next)`: grabs the data stored at `path`,
#    calls `next(err,data)`. If no data is stored there, calls
#    `next(null,null)` (it does not count as an error).  
#
#  - `getSignedUrl(path)`: returns a public access URL for
#    `path`.
#
#  - `glob(expr,cursor,count,next)`: enumerates up to `count`
#    paths that satisfy glob expression `expr`, starting at
#    `start`. Calls `next(err,list,newCursor)`. Cursor is an
#    arbitrary type, the only requirement is that `null` is
#    a valid cursor representing the first element

class Store

  # Use a database driver internally
   
  constructor: (@_db) ->
    
  # Locks and stores an object on a database.
  #
  # Since it is usually necessary to generate the document contents
  # *after* it has been locked (such as in the case of an update),
  # the second argument is a function that returns the content instead
  # of the content itself, and it will be called after the lock is
  # acquired.  
  #
  # Attempting to put `null` will abort the put. Use this when the
  # update function realizes there is no need to perform the update.

  put: (path,getContent,next) ->
    withLock @_db.uid(path), next, (next) =>
      getContent (err,content) =>       
        return next err,  null if err
        return next null, null if content == null
        console.log "db.put #{path}"
        @_db.put path, { Body: content }, (err,data) ->  
          console.log "db.put #{path}: #{err}" if err
          next err, null

  # Grabs an object from a database without a lock.
  #
  # Returns `null` if the object does not exist on S3. Otherwise
  # returns a buffer with the object contents.
 
  get: (path,next) ->
    console.log "db.get #{path}"
    @_db.get path, (err,data) =>
      console.log "db.get #{path}: #{err}" if err
      next err, data

  # Grabs an object from a database without a lock, parses it as JSON.
  #
  # Acts as `get` but applies a JSON parser if the object exists.

  getJSON: (path,next) ->
    @get path, (err,data) ->
      return next err, data if err
      json = null
      if data != null
        try
          data = data.toString 'utf8'    
          json = JSON.parse data
        catch error
          console.log "Could not parse: ", json
          return next "Error parsing JSON", null
      next null, json

  # Locks and updates an object on a database.  
  #
  # `update(path,f,next)` will load the object from `path` and pass
  # its contents to *asynchronous* function `f`. That
  # function then returns the new data using its callback, or
  # `null` if no update should occur.
  #
  # The input data is a buffer or `null`. The output data may be
  # a string or a buffer, or `null` to perform no update.
 
  update: (path,f,next) ->
    getContent = (next) =>
      @get path, (err,data) ->
        return next err, null if err
        f data, next
    @put path, getContent, next

  # Upload a file to a database, using its MD5 as its name.
  # 
  # The path of the generated file is `$prefix/$md5`
  # This operation is idempotent, so no locking is performed.
  #
  # The file argument is expected to contain the following fields:
  #  - `file.path`: a local path where the file is stored.
  #  - `file.content`: the file contents, as a string or buffer
  #  - `file.type`: the MIME-type of the file
  #  - `file.name`: the user-provided name of the file
  #
  # Exactly one of `file.path` and `file.content` must be provided.
  # 
  # Returns the MD5.

  uploadFile: (prefix,file,next) ->
    withFile = (err,content) => 
      return next("When opening file: #{err}", null) if err
      md5 = do -> 
        hash = crypto.createHash 'md5'
        hash.update content
        hash.digest 'hex'
      path = prefix + "/" + md5
      obj = 
        Body: content
        ContentType: file.type
      if file.name
        obj.ContentDisposition = "attachment; filename=#{file.name}"
      console.log "db.put #{path}"
      @_db.put path, obj, (err,data) ->
        console.log "db.put #{path}: #{err}" if err
        next err, md5

    if 'content' of file
      withFile null, file.content
    else
      fs.readFile file.path, withFile

  # Locks and updates a JSON value on a database.
  #
  # Acts as `update`, but the data is parsed as JSON before being
  # passed to `f`, and the return value of `f` (if not `null`)
  # will be serialized back to JSON.
 
  updateJSON: (path,f,next) ->
    f2 = (data,next) ->
      next2 = (err,json) ->
        if typeof json == 'undefined'
          throw "Updater should always return both error and json"
        return next err,  null if err
        return next null, null if json == null
        next null, JSON.stringify json
      if data == null
        f null, next2
      else
        json = do ->
          try 
            JSON.parse data
          catch error
            null
        if json == null
          next "Error parsing JSON", null
        f json, next2
    @update path, f2, next
                         
  # Get a visitable URL, that lasts an entire day.
 
  getUrl: (path) ->
    @_db.getSignedUrl path
    
  # Iterate through a list of all keys that match a certain
  # glob expression.
  #
  # `each(path,next)` is called for each path, and should call
  # `next(bool)` when it has finished processing the path. The
  # boolean should be false to stop processing, true to continue.

  withPrefix: (prefix,each,finish = null) ->

    finish = finish || -> 
    count = 20
    
    processBatch = (start) =>
      @_db.withPrefix prefix, start, count, (err,list,end) ->
        return finish err if err
        return finish null if list.length == 0
        doEach = (i) ->
          return processBatch end if i == list.length 
          each list[i], (keepGoing) ->
            return finish null if !keepGoing
            doEach(i+1)
            
    processBatch null
    
  toString: ->
    "Store @ " + @_db.toString()

# Export the class directly

module.exports = Store
