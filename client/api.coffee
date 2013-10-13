# API connectors: anything API-related goes through here

@API =

  # Post a command to the API server. This function should only be
  # called from this file.
  post: (command,payload,next) ->
    $.ajax
      url: '/api/' + command
      success: next
      error: Error.fatal
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify payload

  # Grab the e-mail of the currently logged in user. This does not
  # query the server, only read from the cookie. Returns null if there
  # is no current user
  getUserEmail: () ->
    try 
      re      = /(?:(?:^|.*;\s*)S\s*\=\s*([^;]*).*$)|^.*$/ 
      cookie  = document.cookie.replace re, "$1"
      session = $.parseJSON cookie
      session.email || null
    catch err
      null

  # Close the current session. Does not query the server, merely discards
  # the local cookie.
  closeSession: (next) ->
    document.cookie = "S="
    do next

  # Start a new session, using the provided assertion. This will update the
  # session cookie if login was successful.
  startSession: (a, next) ->
    API.post 'login', {'assertion':a}, ->
      do next
    
