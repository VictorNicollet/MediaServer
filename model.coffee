require 'coffee-script'
Thread = require './thread-limiter'

# Sets up a model's "get" and "update" functions.
#
# A model is a class with the following interface:
# 
#  - `constructor(id,readonly,json,store)` is called when loading a model
#    instance. The 'id' was provided to either the `get` or
#    `update` function. `readonly` is true if the model was loaded
#    by a `get`. The `json` is the data loaded from the persistent
#    store, `null` if not found. `store` is the store from which the model
#    was loaded.
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

  # These functions are run in parallel after an update occurs.
  # `runOnUpdate(f)` registers function to be called. 

  onUpdate = []

  doOnUpdate = (store, obj, finished) ->
    thread = (f) -> (next) -> f store, obj, next
    Thread.start (thread f for f in onUpdate), finished
                  
  theModule.exports.runOnUpdate = (f) ->
    onUpdate.push f

  # Get an instance using a proof. The proof may be the identifier
  # itself, or have an 'id' member. 

  theModule.exports.get = (store,proof,next) ->
    id = if typeof proof == 'object' && 'id' of proof then proof.id else proof
    url = getUrl id
    store.getJSON url, (err,json) ->
      next err, null if err
      next null, new theClass(proof,true,json,store)

  # Get an instance (same as get), apply an update function. if the update
  # function returns a non-null object, that object is saved back to the
  # database. Triggers `onUpdate` when an update does happen. 

  theModule.exports.update = (store,proof,update,next) ->
    
    id = if typeof proof == 'object' && 'id' of proof then proof.id else proof
    url = getUrl id

    theObject = null
    theChangedObject = null

    realUpdate = (json,next) ->
      update new theClass(proof,false,json,store), (err,obj) ->
        
        theObject = obj
      
        json = null
        if obj != null && (!('hasChanged' of obj) || obj.hasChanged())
          json = obj.serialize()
          theChangedObject = obj
          
        next null, json 

    realNext = (err) ->
      next err, null if err      
      if theChangedObject != null       
        doOnUpdate store, theChangedObject, ->
      next null, theObject
      
    store.updateJSON url, realUpdate, realNext

  # Loads the specified instances, calls the "touch" function, then calls
  # onUpdate on each instance.

  theModule.exports.touch = (store,ids,next) ->
    doLoop = (i) ->
      if i < ids.length 
        theModule.exports.get store, ids[i], (err,obj) ->
          return if err || obj == null
          do obj.touch if 'touch' of obj
          doOnUpdate store, obj, ->
            doLoop(i+1)
      else if next
        do next
    doLoop 0 

