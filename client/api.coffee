# API connectors: anything API-related goes through here

@API =

  # Assign a function to this member to specify what should happen when
  # an error occurs. 
  onError: (text) ->

  # An error happened. Consider this function private.
  error: (text) ->
    do API.requests.clear
    API.requests.isRunning = false      
    API.onError text

  # Post a command to the API server. Consider this function private.
  post: (command,payload,next) ->
    $.ajax
      url: '/api/' + command
      success: (data) ->
        if "error" of data
          error data.error
        else
          next data
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify payload
      error: (xhr,error) ->
        switch error
          when "timeout" then API.error "Request timed out"
          when "error" then API.error "HTTP error occurred"
          when "parsererror" then API.error "Server returned garbled data"
      
  # Grab the e-mail of the currently logged in user. This does not
  # query the server, only read from the cookie. Returns null if there
  # is no current user
  getUserEmail: () ->
    try 
      re      = /(?:(?:^|.*;\s*)S\s*\=\s*([^;]*).*$)|^.*$/ 
      cookie  = document.cookie.replace re, "$1"
      session = $.parseJSON unescape cookie
      session.email || null
    catch err
      null

  # ================================================================================
  # Session-related actions
  session:

    # Close the current session. Does not query the server, merely discards
    # the local cookie.
    close: (next) ->
      document.cookie = "S="
      do next

    # Start a new session, using the provided assertion. This will update the
    # session cookie if login was successful. Also starts the API processing
    # as soon as possible.
    start: (a, next) ->
      API.post 'login', {'assertion':a}, ->
        do API.requests.process if !API.requests.isRunning
        do next

  # ================================================================================
  # Request-related operations. Everything in here is private.
  requests:
    
    # Except for the session operations, all requests are queued until they
    # can be performed. This is the queue.
    queue: []

    # Is a request currently running ? 
    isRunning: false

    # When the page changes, the queue is cleared (it is no longer useful)
    clear: -> API.requests.queue = []
  
    # Called right after a request finished, OR after the user logged in.
    # Processes the next request, if any.
    process: ->
      r = API.requests
      if r.queue.length > 0
        r.queue.shift()(next)
        r.isRunning = true
      else
        r.isRunning = false
   
    # Attempt to spawn a new request if no requests are currently running,
    # or enqueue the request for delayed execution. Consider this as a
    # private function.
    start: (req) ->
      r = API.requests
      if r.isRunning || r.queue.length > 0
        r.queue.push req
      else
        r.isRunning = true
        req r.process

  # ================================================================================
  # Albums
  album:

    # Create a new album with the provided name, available only to myself.
    # Returns the full album object as generated by the server
    create: (name,next) ->
      API.requests.start (next) ->
        API.post "album/create", {"name":name}, (data) ->
          next data.id
