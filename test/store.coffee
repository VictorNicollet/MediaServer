require 'coffee-script'
Store = require '../store'
Mock = require '../store-mock'

# Reading a key with no associated data is not an error, and
# should return null

exports["test store#getObject on missing key"] = (beforeExit,assert) ->
  store = new Store(new Mock) 
  store.get "missing", (err,data) ->
    assert.isNull err
    assert.isNull data

content = (c) -> (next) -> next null, c

# Putting an object with a valid key should not fail

exports["test store#putObject"] = (beforeExit, assert) ->
  store = new Store(new Mock)
  store.put "put", content("foo"), (err) ->
    assert.isNull

# Reading an object that was put should not fail

exports["test store#getObject on put key"] = (beforeExit, assert) ->
  store = new Store(new Mock) 
  store.put "put", content("FOO"), (err) ->
    store.get "put", (err,data) ->
      assert.isNull err
      assert.eql "FOO", data

# Reading two put objects should grab the valid data for each

exports["test store#getObject on two put keys"] = (beforeExit, assert) ->
  store = new Store(new Mock) 
  store.put "foo", content("FOO"), (err) ->
    store.put "bar", content("BAR"), (err) ->
      store.get "foo", (err,data) ->
        assert.eql "FOO", data
      store.get "bar", (err,data) ->
        assert.eql "BAR", data

# Reading through objects with glob

exports["test store#withPrefix"] = (beforeExit, assert) ->

  found = []
  ok = false
            
  store = new Store(new Mock)
  store.put "foo/0", content("FOO0"), (err) ->
    store.put "bar/1", content("BAR1"), (err) ->
      store.put "barquux", content("BARQUUX"), (err) ->
        store.put "bar/2", content("BAR2"), (err) ->
          each = (path,next) ->
            found.push path
            next true
          store.withPrefix "bar", each, ->
            ok = true
            
  beforeExit ->
    assert.eql ["1","2"], found
    assert.ok ok       
