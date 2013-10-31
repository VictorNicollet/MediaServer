require 'coffee-script'
AWS = require 'aws-sdk'
crypto = require 'crypto'
fs = require 'fs'
MutexHash = require './mutex-hash'

# Configuration

bucket = 'docs.nicollet.net'

if fs.existsSync "./s3.json"
  prefix = 'dev'
  AWS.config.loadFromPath './s3.json'
else
  prefix = 'alix.et.victor'
  AWS.config.update
    region: "eu-west-1"
    accessKeyId: process.env.S3KEY
    secretAccessKey: process.env.S3SECRET

S3 = new AWS.S3()

# Build a basic `{Bucket,Key}` object from a path. An optional
# second parameter takes an object to be extended instead of
# creating a new one.

makeParams = (path,extend=null) ->
  extend = {} if extend == null
  extend.Bucket = bucket
  extend.Key = prefix + '/' + path
  extend

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

# Reformats a complex Amazon S3 message into a more human-friendly
# one. If `null` is passed, returns `null`.

error = (err) ->
  if err == null then null else "Error connecting to Amazon S3"

# Despite being high-availability, sometimes S3 times out on some
# requests. Usually, it is enough to try the same request again.
# `retry(action,retries)(args,next)` will call `action(args,next)`
# until it succeeds or `retries` times, whichever comes first.
#
# For the purposes of this function, failure is defined as calling
# `next` with a non-null error parameter.

retry = (action,retries=3) ->
  (args, next) ->
    recurse = (retries) ->
      action args, (err,data) ->
        if err != null && retries > 0
          recurse(retries-1)
        else
          next err, data
    recurse retries

putObjectRetry = retry (obj,next) -> S3.putObject obj, next
getObjectRetry = retry (obj,next) -> S3.getObject obj, next

# Locks and stores an object on S3.
#
# Since it is usually necessary to generate the document contents
# *after* it has been locked (such as in the case of an update),
# the second argument is a function that returns the content instead
# of the content itself, and it will be called after the lock is
# acquired.
#
# Attempting to put `null` will abort the put. Use this when the
# update function realizes there is no need to perform the update.

module.exports.put = (path,getContent,next) ->
  params = makeParams path
  withLock params, next, (next) ->
    getContent (err,content) ->       
      return next err,  null if err
      return next null, null if content == null
      params.Body = content
      console.log "S3.putObject #{params.Key}"
      putObjectRetry params, (err,data) ->  
        console.log "S3.putObject #{params.Key}: #{err}" if err
        next error(err), null

# Grabs an object from S3 without a lock.
#
# Returns `null` if the object does not exist on S3. Otherwise
# returns a buffer with the object contents.
 
module.exports.get = (path,next) ->
  params = makeParams path
  console.log "S3.getObject #{params.Key}"
  getObjectRetry params, (err,data) ->
    err = null if /^NoSuchKey/.test err
    console.log "S3.getObject #{params.Key}: #{err}" if err
    data = if data == null then null else data.Body
    next error(err), data

# Grabs an object from S3 without a lock, parses it as JSON.
#
# Acts as `get` but applies a JSON parser if the object exists.

module.exports.getJSON = (path,next) ->
  module.exports.get path, (err,data) ->
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

# Locks and updates an object on S3.
#
# `update(path,f,next)` will load the object from `path` and pass
# its contents to *asynchronous* function `f`. That
# function then returns the new data using its callback, or
# `null` if no update should occur.
#
# The input data is a buffer or `null`. The output data may be
# a string or a buffer, or `null` to perform no update.
 
module.exports.update = (path,f,next) ->
  getContent = (next) ->
    module.exports.get path, (err,data) ->
      return next err, null if err
      f data, next
  module.exports.put path, getContent, next

# Locks and updates a JSON value on S3
#
# Acts as `update`, but the data is parsed as JSON before being
# passed to `f`, and the return value of `f` (if not `null`)
# will be serialized back to JSON.
 
module.exports.updateJSON = (path,f,next) ->
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
   module.exports.update path, f2, next  

# Upload a file to S3, using its MD5 as its name.
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

module.exports.uploadFile = (prefix,file,next) ->
  withFile = (err,content) -> 
    return next("When opening file: #{err}", null) if err
    md5 = do -> 
      hash = crypto.createHash 'md5'
      hash.update content
      md5 = hash.digest 'hex'
    params = makeParams [prefix,md5].join('/'),  
      Body: content
      ContentType: file.type
      ContentDisposition: "attachment; filename=#{file.name}"
    console.log "S3.putObject #{params.Key}"
    putObjectRetry params, (err,data) ->
      console.log "S3.putObject #{params.Key}: #{err}" if err
      next error(err), md5

  if 'content' of file
    withFile null, file.content
  else
    fs.readFile file.path, withFile
                     
# Get a visitable URL, that lasts an entire day.
 
module.exports.getUrl = (path) ->
  S3.getSignedUrl 'getObject', makeParams path

# Run this module in testing mode

module.exports.testMode = ->
  S3 = require('./store-mock')
  @
