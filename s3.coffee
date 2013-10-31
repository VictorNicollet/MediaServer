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
S3.prefix = prefix
S3.bucket = bucket
S3.toString = ->
   "S3 #{bucket}/#{prefix}"

module.exports = S3
