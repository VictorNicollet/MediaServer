require 'coffee-script'
fs = require 'fs'

# In-memory storage that mocks the S3 module used by `store`.

buckets = {}

getBucket = (bucket) ->
  buckets[bucket] || (buckets[bucket] = {})

# Replacement for S3.putObject

module.exports.putObject = (obj,next) ->
  getBucket(obj.Bucket)[obj.Key] = obj.Content
  next null

# Replacement for S3.getObject

module.exports.getObject = (obj,next) ->
  bucket = getBucket obj.Bucket
  if obj.Key of bucket
    next null, bucket[obj.Key]
  next "NoSuchKey", null

# Replacement for S3.getSignedUrl

module.exports.getSignedUrl = (obj) ->
  'https://' + obj.Bucket + '.s3.amazonaws.com/' + obj.Key
  
