do ->

  # Clears all pending requests. Called when an error happens or when a
  # new route is dispatched.
  
  clear = ->

    runs = false
    reqs = []

  $c.on 'route', clear

  # Called when an error happens, with the error message as its argument.
  # It clears all the current pending requests and displays the message.
  #
  # Triggers the `fail` event on the container.

  @error = (t) ->
    
    id = 'error'
    $('#'+id).remove()
    new R($c)
      .open('div',{ id:id, class:'alert alert-danger alert-dismissable' })
      .open('button',{ type: 'button', class:'close' }, (r) -> r.$.remove())
      .show()

    $c.trigger 'fail'
    do clear

  # Parses a server response. Returns either null (if an error happened)
  # or the provided data object.
  #
  # If errors happen, triggers a `fail` event on the container.

  @parse = (r) ->
    
    if r.requiresLogin
      $c.trigger 'fail'
      do clear
      do persona
      return null

    if 'error' of r
      error r.error
      return null
      
    return r

  n = 0

  # Run a query against the server. This is a generic function, the
  # definitions for specific GET and POST functions are below.

  q = (method) -> (what,data,next) ->
    i = ++n
    post = method == 'POST'
    $.ajax
      url: '/api/' + what
      success: (r) -> next parse r
      type: method
      cache: !post 
      contentType: 'application/json'
      data: if post then JSON.stringify data else data
      error: (x,e) ->
        error switch e
          when 'timeout' then "Request timed out"
          when 'error' then "HTTP error occured"
          when 'parseerror' then "Server returned garbled data"

  @get  = q "GET"
  @post = q "POST"

  # Running requests: uses a queue to run the requests in sequential
  # order.

  reqs = []
  runs = false

  # This function runs the next request, if any. Should only be called
  # if no request is currently running, but will not perform that
  # check on its own (use `lock()` for that instead).
  
  run = ->
    if runs = (reqs.length > 0)
      reqs.shift()(run)

  # Starts the model, if not already running.

  @model = ->
    run() if !runs

  # Locks the model engine (which ensures only one request can be sent
  # at a time), and runs the request. The request is a function with
  # a single callback argument `unlock` that should be called to
  # release the lock.

  @lock = (f) ->
    reqs.push f
    model()

  # A list model. Uses a list identifier (what the list is) and an
  # item identifier (what in item is).  
  #
  # Argument is a function that queries the entire list, based on
  # a list identifier.

  @List = (f) ->
    
    # The function used to load data.
    @f = f

    # The identifier of the currently loaded list.
    @id = null

    # This cache contains each element in the currently loaded
    # list, by item-id.
    @c = {}

    @

  List.prototype = 

    # Loads a fresh list by its id, and returns the elements
    # asynchronously.
      
    all: (l,n) ->
      @f l, (r) =>
        @id = l
        @c = {}
        for it in (@l = r)
          id = it
          id = id.id while typeof id == 'object'
          @c[id] = it
        n @l

    # Grabs the cached value of the specified item in the specified
    # list. Does nothing if expired, loads if present.

    get: (l,i,n) ->
      rec = (c) =>
        if l == @id && i of @c 
          n @c[i]
        else if c
          @all l, -> rec false
        else
          n null
      rec true 

    # Grabs a proof of the cached value. Assumes that the item contains
    # a field 'id' which is a standard proof (that is, it contains
    # an expired field).

    proof: (l,i,n) ->
      rec = (c) =>
        if l == @id && i of @c && @c[i].id.expires.notYet()
          n @c[i].id
        else if c
          @all l, -> rec false
        else
          n null
      rec true 

    
