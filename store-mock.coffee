require 'coffee-script'
fs = require 'fs'

# In-memory storage that mocks the S3 module used by `store`.

current = 1

class StoreMock

  constructor: ->
    @_keys = {}
    @_id   = "" + current++

  uid: (path) ->
    "mockdb://#{@_id}/#{path}"

  put: (path,obj,next) ->
    @_keys[path] = obj.Body
    next null

  get: (path,next) ->
    if path of @_keys
      return next null, @_keys[path] 
    next null, null

  getSignedUrl: (path) ->
    'https://test/' + path

  withPrefix: (prefix,start,count,next) ->

    prefix = prefix + '/' if ! /\/$/.test prefix
    clean  = prefix.replace(/[\[\].*+?{}()|^\\$]/g,"\\$1")
    regexp = new RegExp("^"+clean)

    matching = (key for key of @_keys when regexp.test key)
    
    start = start || 0

    if start > matching.length
      result = []
    else if start + count > matching.length 
      result = matching[start..]
    else
      result = matching[start..start+count-1]

    start = if start + count > matching.length then null else start + count

    next(null, result, start)
    
  toString: ->
    "Mock DB #{@_id}"

# Export the class as a whole
  
module.exports = StoreMock
