require 'coffee-script'

# An item inside the cache

class Item

  # Decay factor is 2s. An exponentially decreasing value is
  # considered to reach zero after about 5 times the decay
  # factor.

  decay: 2000

  constructor: (@data, @time) ->
    @init = 1

  score: (now) ->
    @init * Math.exp( - (now - @time) / @decay )

# A cache that stores any data loaded from remote storage
# to avoid using up too much bandwidth.
#
# Each loaded item is a string, and has associated information:
# the last time it was accessed, and the score for that access.
# Score increases by 1 for each access, and decreases exponentially
# (it reaches zero after about ten seconds).

class StoreCache

  constructor: (@maxsize) ->
    @values = {}
    @size = 0

  # Update the cache by removing a value from it

  unset: (key) ->

    if key of @values
      @size -= @values[key].data.length
      delete @alues[key]
      
  # Update the cache by adding a value to it.
  
  set: (key,value) ->

    return if value == null

    now = +new Date()
    score = 1
    
    if key of @values
      v = @values[key]
      @size += v.data.length - value.length 
      score += v.score now
      v.data = value
      v.time = now
      v.init = score
    else
      @values[key] = new Item value, now
      @size += value.length
      
    cleanup now while @size > @maxsize
    
  # Get a value from the cache.

  get: (key) ->

    if key of @values
      @values[key].data
    else
      null

  # Clean up the cache by finding the lowest score and
  # removing it.

  clean: (now) ->

    lowestScore = 0
    lowest = null
    
    for key, value of @values
      score = value.score now
      if lowest == null || lowestScore > score
        lowest = key
        lowestScore = score

    return if lowest == null

    @size -= @values[key].data.length
    delete @values[key]

 
module.exports = StoreCache
