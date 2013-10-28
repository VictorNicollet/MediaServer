require 'coffee-script'

# A mutex hash grants exclusive locks on resources identified by keys.
# See the 'run' method for detailed information.

class MutexHash

  # Locks are always released after the timeout duration (in milliseconds)
  # has elapsed, even if the locking action has not returned yet.

  constructor: (@timeout=60000) ->
    @_hashes = {}

  # Locks the resource identified by 'key', and runs 'action' with 'next' as
  # its callback.
  #
  # The lock is acquired right before the call to 'action', and released
  # right before the call to 'next'.
  #
  # If the resource is currently locked, the action is delayed until the
  # lock is released. Multiple actions may wait on a single resource, they
  # are executed in the order they were passed to 'run'. 

  run: (key, next, action) ->

    # This wrapper ensures that 'end' will always be called, either
    # because the action finished or because it timed out.
  
    hasFinished = false
    finish = (unlock) ->
      return if hasFinished 
      hasFinished = true
      do unlock
      
    wrapped = (unlock) =>
      try
        setTimeout (-> finish unlock), @timeout
        action (err,res) ->
          finish unlock 
          next err, res
      catch error
        finish unlock
        throw error

    # This function is called whenever a lock is released. It either
    # runs the next action in the sequence, or removes the lock
    # marker from the resource entirely.

    runNextAction = =>
      if key of @_hashes
        if @_hashes[key].length == 0
          return delete @_hashes[key]
        nextAction = do @_hashes[key].shift
        nextAction runNextAction

    # If there is a waiting list bound to the resource, then that
    # resource is currently locked: enqueue the action, it will
    # be run when the lock is released.     

    if key of @_hashes
      @_hashes[key].push wrapped
    else
      @_hashes[key] = [wrapped]
      do runNextAction

      
module.exports = MutexHash
