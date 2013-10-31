require 'coffee-script'
Index = require '../index'
Store = require '../store'
Mock  = require '../store-mock'

# Queries from an empty index are always empty

exports["test Index#query when empty"] = (beforeExit, assert) ->
  store = new Store(new Mock)
  index = new Index "prefix"

  index.query(store,"missing").run (err,list,count) ->
    assert.eql list, []
    assert.eql count, 0
    
