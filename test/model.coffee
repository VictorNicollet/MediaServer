require 'coffee-script'
Store = require '../store'
Mock  = require '../store-mock'
Model = require '../model'

# A mock model used for testing values
 
class MockModel

  constructor: (@proof,@readonly,@json,@store) ->
    @changed = false
    
  serialize: -> @json
  hasChanged: -> @changed 

model = { exports: {} }
Model.define model, MockModel, (id) -> "id:#{id}"

content = (value) -> (next) -> next null, value

# 'get' on a missing object still creates an instance with
# a null JSON

exports["test model#define: 1"] = (beforeExit, assert) ->

  store = new Store(new Mock)
  model.exports.get store, "a", (err,m) ->
    assert.isNull err
    assert.eql    m.proof, "a"
    assert.ok     m.readonly
    assert.isNull m.json
    assert.eql    m.store, store

 
# 'get' on a created object loads the JSON for that object.

exports["test model#define: 2"] = (beforeExit, assert) ->

  store = new Store(new Mock)
  store.put "id:a", content('{"a":"b"}'), ->
    model.exports.get store, "a", (err,m) ->
      assert.isNull err
      assert.eql    m.proof, "a"
      assert.ok     m.readonly
      assert.eql    m.json, { a: "b" }
      assert.eql    m.store, store

# 'update' on a non-changed object does nothing

exports["test model#define: 3"] = (beforeExit, assert) ->

  store = new Store(new Mock)
  store.put "id:a", content('{"a":"b"}'), ->
    update = (m,next) ->
      assert.isNull err
      assert.eql    m.proof, "a"
      assert.ok     !m.readonly
      assert.eql    m.json, { a: "b" }
      assert.eql    m.store, store
      m.json.a = "c"
      next null, m 
    model.exports.update store, "a", ->
      store.get "id:a", (err,data) ->
        assert.eql '{"a":"b"}', data

# 'update' on a changed object writes data to the store

exports["test model#define: 4"] = (beforeExit, assert) ->

  store = new Store(new Mock)
  store.put "id:a", content('{"a":"b"}'), ->
    update = (m,next) ->
      m.json.a = "c"
      m.changed = true
      next null, m
    model.exports.update store, "a", update, ->
      store.get "id:a", (err,data) ->
        assert.eql '{"a":"c"}', data
        
