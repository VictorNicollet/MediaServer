# Shorthand reference to the document
doc = document

# Array.seek calls a function on every item in
# an array until one of them returns true. 

Array::seek = (f) ->
  for x in @
    if f x
      return 

# The container will be loaded later, but other pieces of the
# system may need to set up event listeners before that happens,
# so provide a way to do that.

@$c =
  on: (e,f) -> $ -> $c.on(e,f)

$ =>

  # Shorthand reference to the container
  @$c = $ '#container'
