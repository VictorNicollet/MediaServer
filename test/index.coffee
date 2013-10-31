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

# Adding a single key binding makes it appear in queries

exports["test Index#add > Index#query"] = (beforeExit, assert) ->  
  store = new Store(new Mock)
  index = new Index "prefix"

  index.add store, "nicollet", "Victor Nicollet", [["male","victor"]], ->
    index.query(store,"male").run (err,list,count) ->
      assert.eql count, 1
      assert.eql list, [["victor","nicollet","Victor Nicollet"]]
      
