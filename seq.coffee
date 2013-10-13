require "coffee-script"

# Runs every function in an array of async
# functions, calls next when it's finished
module.exports.run = (array, next) ->
  recurse = (i) ->
    return next() if i == array.length
    f = array[i]
    f () -> recurse (i+1)
  recurse 0

# Applies async function f to every item of
# the array, calls next when it's finished
module.exports.iter = (f, array, next) ->
  recurse = (i) ->
    return next() if i == array.length
    f array[i], () -> recurse (i+1)
  recurse 0
  
