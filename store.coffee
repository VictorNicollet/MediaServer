require 'coffee-script'
AWS = require 'aws-sdk'
crypto = require 'crypto'
fs = require 'fs'

# Configuration
bucket = 'pics.nicollet.net'
prefix = 'dev'

AWS.config.loadFromPath './s3.json'
S3 = new AWS.S3()

# This module serializes all write operations.
writeQueue = []
isRunning = false

onActionFinished = () ->
  if writeQueue.length == 0
    isRunning = false
  else
    action = do writeQueue.shift
    action onActionFinished

run = (action) ->
  if isRunning
    writeQueue.push action
  else
    isRunning = true
    action onActionFinished

# The default error message
error = "Error connecting to Amazon S3"

# Functions with retrying
putObjectRetry = (obj, next, retries = 3) ->
  S3.putObject obj, (err,data) ->
    if err && retries > 0
      putObjectRetry obj, next, retries-1
    else
      next err, data
    
getObjectRetry = (obj, next, retries = 3) ->
  S3.getObject obj, (err, data) ->  
    if err && retries > 0
      getObjectRetry obj, next, retries-1
    else
      next err, data

# Generic file storage function
put = (path,getContent,next) ->
  run (done) ->
    getContent (err,content) -> 
      return next(err) if err
      obj =
        Bucket: bucket
        Key: prefix + '/' + path
        Body: content
      putObjectRetry obj, (err,data) ->
        do done
        console.log "S3.putObject #{obj.Key}: #{err}" if err 
        next(if err then error else null)

# Generic file query function
get = (path,next) ->
  obj =
    Bucket: bucket
    Key: prefix + '/' + path
  getObjectRetry obj, (err,data) ->
    err = null if /^NoSuchKey/.test err
    console.log "S3.getObject #{obj.Key}: #{err}" if err
    err = error if err
    data = if data == null then null else data.Body
    next err, data

# Grab JSON data
getJSON = (path,next) ->
  get path, (err,data) ->
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
    
module.exports.getJSON = getJSON

# Update a value on S3
update = (path,f,next) ->
  getContent = (next) ->
    get path, (err,data) ->
      return next err, null if err
      f data, next
  put path, getContent, next

module.exports.update = update

# Update a JSON value on S3
updateJSON = (path,f,next) ->
  f2 = (data,next) ->
    next2 = (err,json) ->
      if typeof json == 'undefined'
        throw "Updater should always return both error and json"
      return next err, null if err
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
   update path, f2, next  

module.exports.updateJSON = updateJSON

# Upload a file to S3, using its MD5 as its name
uploadFile = (prefix2,file,next) ->
  hash = crypto.createHash 'md5'
  s = fs.createReadStream file.path   
  s.on 'error', -> next "Error reading downloaded file", null
  s.on 'data', (d) -> hash.update d
  s.on 'end', ->
    fs.readFile file.path, (err,buffer) ->
      return next err, null if err 
      md5 = hash.digest 'hex'
      obj =
        Body: buffer
        Key: [prefix,prefix2,md5].join '/'
        Bucket: bucket
        ContentType: file.type
        ContentDisposition: "attachment; filename=#{file.name}"
      run (done) ->
        putObjectRetry obj, (err,data) ->
          do done
          console.log "S3.putObject #{obj.Key}: #{err}" if err
          return next err, null if err
          next null, md5
                     
module.exports.uploadFile = uploadFile


# Upload a file to S3, using its MD5 as its name
uploadFileFromString = (prefix2,file,next) ->
  hash = crypto.createHash 'md5'
  hash.update file.content  
  md5 = hash.digest 'hex'
  obj =
    Body: file.content
    Key: [prefix,prefix2,md5].join '/'
    Bucket: bucket
    ContentType: file.type
    ContentDisposition: "attachment; filename=#{file.name}"
  run (done) ->
    putObjectRetry obj, (err,data) ->
      do done
      console.log "S3.putObject #{obj.Key}: #{err}" if err
      return next err, null if err
      next null, md5
                     
module.exports.uploadFileFromString = uploadFileFromString

# Get a visitable URL, that lasts an entire day
getUrl = (key) ->
  obj =
    Bucket: bucket
    Key: prefix + "/" + key
  S3.getSignedUrl 'getObject', obj

module.exports.getUrl = getUrl
