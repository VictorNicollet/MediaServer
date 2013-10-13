# API connectors: anything API-related goes through here
@API =

  # Grab the e-mail of the currently logged in user. This does not
  # query the server, only read from the cookie. Returns null if there
  # is no current user
  getUserEmail: () ->
    try 
      re      = /(?:(?:^|.*;\s*)S\s*\=\s*([^;]*).*$)|^.*$/ 
      cookie  = document.cookie.replace re, "$1"
      session = eval cookie
      session.email || null
    catch err
      null

  # Close the current session. Does not query the server, merely discards
  # the local cookie.
  closeSession: () ->
    document.cookie = "S="

  startSession: (assert) ->
    

    
