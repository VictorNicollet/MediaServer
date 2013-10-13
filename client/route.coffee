# Routing based on the page URL
@Route =

  # All the registered routes. Each is a function that returns true
  # if it matches, false otherwise.
  routes: [],

  # Register a new route. Path may be a regexp or a string.
  register: (path, action) ->

    # String routes are special cases of regexp routes
    if typeof path == 'string'
      path = '^' + path.replace(/[*]/g, '([^/]*)') + '$'
      path = new RegExp path

    # Running a route clears anything that was running on the
    # old route
    run = (action, args) ->
      do API.requests.clear
      $c = $ '#container'    
      $c.html ''
      action args, (html) -> $c.html html
      
    Route.routes.push (realpath) ->
      if path.test realpath
        run action, realpath.match(path)[1..]
        true
      else
        false

  # Reach a route. 
  dispatch: (path = null) ->    
    path = document.location.pathname if path == null
    console.log "Dispatch: %s", path
    for item in Route.routes
      return if item path

  # Reach a route. Updates the browser's current URL.
  go: (path) ->
    history.pushState null, null, path
    dispatch path

# When state is popped, use the current path to dispatch 
@onpopstate = (event) ->
  do Route.dispatch


    
    
