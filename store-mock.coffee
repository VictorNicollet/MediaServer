require 'coffee-script'
fs = require 'fs'

# In-memory storage that mocks the S3 module used by `store`.

current = 1

class StoreMock

  constructor: ->
    @buckets = {}
    @bucket = "test"
    @prefix = "" + current++

  getBucket: (bucket) ->
    @buckets[bucket] || (@buckets[bucket] = {})

  # Replacement for S3.putObject

  putObject: (obj,next) ->
    @getBucket(obj.Bucket)[obj.Key] = obj.Body
    next null

  # Replacement for S3.getObject

  getObject: (obj,next) ->
    bucket = @getBucket obj.Bucket
    if obj.Key of bucket
      return next null, { Body: bucket[obj.Key] }
    next "NoSuchKey", null

  # Replacement for S3.getSignedUrl

  getSignedUrl: (obj) ->
    'https://' + obj.Bucket + '.s3.amazonaws.com/' + obj.Key

  toString: ->
    "Mock DB #{@prefix}"

# Export the class as a whole
  
module.exports = StoreMock
