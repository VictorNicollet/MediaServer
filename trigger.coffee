require 'coffee-script'

# Triggering events manually.

module.exports.make = ->
  
  registeredCallback = null
  args = null

  send = ->
    if registeredCallback != null && args != null
      registeredCallback.call(@,args)

  trigger =
  
    onReceive: (callback) ->
      
      if registeredCallback != null
        throw "Callback is already registered"

      registeredCallback = callback
      do send
    
    send: ->
      
      if args != null
        throw "Trigger has already fired"
      
      args = arguments
      do send
      
  trigger  
  
