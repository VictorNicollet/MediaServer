require 'coffee-script'
AWS = require 'aws-sdk'
fs = require 'fs'

# Loads the S3 configuration and exports the S3 object.

if fs.existsSync "./s3config.json"
  prefix = 'dev'
  AWS.config.loadFromPath './s3config.json'
else
  prefix = 'alix.et.victor'
  AWS.config.update
    region: "eu-west-1"
    accessKeyId: process.env.S3KEY
    secretAccessKey: process.env.S3SECRET

bucket = 'docs.nicollet.net'

S3 = new AWS.S3()

# Generic error message sent back to the user when something goes
# wrong with Amazon S3

S3ERR = "Error connecting to Amazon S3"

# The wrapper implements the database interface expected by `Store`
# using the Amazon S3 client API. 

wrapper =
  S3: S3
  prefix: prefix
  bucket: bucket
  toString: ->
   "S3 #{bucket}/#{prefix}"

  uid: (path) ->
    "S3://#{bucket}/#{prefix}/#{path}"

  get: (path,next) ->
    obj =
      Bucket: @bucket
      Key: @prefix + '/' + path
    retry (n) =>
      @S3.getObject obj, (err,data) ->
        if err != null
          if /^NoSuchKey/.test err
            next null, null
          else if n > 0
            retry(n-1)
          else
            next S3ERR, null
        else
          next null, data.Body
    retry 5

  set: (path,theObj,next) ->
    obj = {}
    obj[k] = v for k, v of theObj
    obj.Bucket = @bucket
    obj.Key = @prefix + '/' + path
    retry (n) =>
      @S3.putObject obj, (err) ->
        if err != null
          if n > 0
            retry(n-1)
          else
            next S3ERR
        else
          next null
    retry 5

  getPublicUrl: (path) ->
    obj =
      Bucket: @bucket
      Key: @prefix + '/' + path
    @S3.getPublicUrl 'getObject', obj

  withPrefix: (prefix,cursor,count,next) ->

    prefix = prefix + '/' if ! /\/$/.test prefix

    query =
      Bucket: @bucket
      Prefix: @prefix + '/' + prefix
      MaxKeys: count

    if cursor
      query.Marker = cursor

    @S3.listObjects query, (err,data) ->

      return next err, null, null if err
      
      keys = (item.Key for item in data.Contents)
      keys.sort()
      keys.shift() if keys.length > 0 && keys[0] == cursor

      cursor = null
      if data.IsTruncated && keys.length > 0 
        cursor = keys.pop()

      next null, keys, cursor
          
module.exports = wrapper
