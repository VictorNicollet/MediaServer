require 'coffee-script'
Store = require './store'

# Sets up a model's "get" and "update" functions.
#
# A model is a class with the following interface:
# 
#  - `constructor(id,readonly,json)` is called when loading a model
#    instance. The 'id' was provided to either the `get` or
#    `update` function. `readonly` is true if the model was loaded
#    by a `get`. The `json` is the data loaded from the persistent
#    store, `null` if not found.
#
#  - `@serialize()` should return a JSON representation of the
#    object in the format expected by the constructor. This JSON
#    will be saved to the database.
#
#  - `@hasChanged()` should return true if the model instance
#    underwent changes that should be written back to the persistent
#    store
#
# Parameter `url(id)` should return the URL of the object with
# identifier `id` on the persistent store.

module.exports.define = (theModule,theClass,getUrl) ->

  theModule.exports.get = (proof,next) ->
    id = if typeof proof == 'object' && 'id' of proof then proof.id else proof
    url = getUrl id
    Store.getJSON url, (err,json) ->
      next err, null if err
      next null, new theClass(proof,true,json)

  theModule.exports.update = (proof,update,next) ->
    
    id = if typeof proof == 'object' && 'id' of proof then proof.id else proof
    url = getUrl id

    theObject = null

    realUpdate = (json,next) ->
      update new theClass(proof,false,json), (err,obj) ->
        
        theObject = obj
      
        json = null
        if obj != null && (!('hasChanged' of obj) || obj.hasChanged())
          json = obj.serialize()
         
        next null, json 

    realNext = (err) ->
      next err, null if err
      next null, theObject
  
    Store.updateJSON url, realUpdate, realNext
    
