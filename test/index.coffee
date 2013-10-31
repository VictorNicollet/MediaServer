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

# Adding multiple key bindings makes them appear in queries
      
exports["test Index#add* > Index#query"] = (beforeExit, assert) ->  
  store = new Store(new Mock)
  index = new Index "prefix"

  index.add store, "nicollet", "Victor Nicollet", [["male","victor"],["male","nicollet"]], ->
    index.add store, "einstein", "Albert Einstein", [["male","albert"],["male","einstein"]], ->
      index.query(store,"male").run (err,list,count) ->
        assert.eql count, 4
        assert.eql list, [
          ["albert", "einstein", "Albert Einstein"],
          ["einstein", "einstein", "Albert Einstein"],
          ["nicollet", "nicollet", "Victor Nicollet"],
          ["victor", "nicollet","Victor Nicollet"]
        ]

# Adding and removing a key binding

exports["test Index#add** > Index#query"] = (beforeExit, assert) ->
  store = new Store(new Mock)
  index = new Index "prefix"

  index.add store, "nicollet", "Victor Nicollet", [["JavaScript","5"]], ->
    index.add store, "nicollet", "Victor Nicollet", [["CoffeeScript","4"]], ->

      index.query(store,"JavaScript").run (err,list,count) ->
        assert.eql list, []
        assert.eql count, 0
 
      index.query(store,"CoffeeScript").run (err,list,count) ->
        assert.eql count, 1
        assert.eql list, [["4","nicollet","Victor Nicollet"]]

