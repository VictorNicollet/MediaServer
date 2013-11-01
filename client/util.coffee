# Shorthand reference to the document
doc = document

# Array.seek calls a function on every item in
# an array until one of them returns true. 

Array::seek = (f) ->
  for x in @
    if f x
      return 

$ =>

  # Shorthand reference to the container
  @$c = $ '#container'
