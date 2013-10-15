require 'coffee-script'
AWS = require 'aws-sdk'

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

# Generic file storage function
put = (path,getContent,next) ->
  run (done) ->
    getContent (err,content) -> 
      return next(err) if err
      obj =
        Bucket: bucket
        Key: prefix + '/' + path
        Body: content
      S3.putObject obj, (err,data) ->
        do done
        next(if err then error else null)

# Generic file query function
get = (path,next) ->
  next null, null # TODO

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
      return next err, null if err
      next null, JSON.stringify json
    if data == null
      f null, next2
    else
      try 
        json = JSON.parse data
        f json, next2
      catch error
        next "Error parsing JSON", null
  update path, f2, next  

module.exports.updateJSON = updateJSON
