# Use AJAX to load pages whenever possible.

do ->

  # All the registered routes. Each is a function that returns true
  # if it matches the provided input, false otherwise.

  routes = []

  # Define new routes from regular expressions or strings.
   
  RegExp::route = (f) ->
    re = @
    routes.push (p) ->
      if t = re.test p 
        $c.html('').trigger 'route'
        f new R($c), p.match(re)[1..]
      t
      
  String::route = (f) ->
    new RegExp('^' + @replace(/\*/g,'([^/]*)') + '$').route(f) 

  # Dispatches to the specified path or, if no path is specified,
  # the current URL

  route = (p) ->
    p = if typeof p == 'string' then p else doc.location.pathname
    routes.seek (r) -> r p 
        
  # Go to the specified path. Sets the browser's URL to that value,
  # the runs a dispatch.
  
  @go = (p) ->
    history.pushState null, null, p 
    go p 

  if 'pushState' of history

    @onpopstate = route
             
    $('body').on 'click', 'a', ->
      if doc.location.host != @host
        return true        
      event.stopPropagation()
      go @pathname
      false

  $ route
