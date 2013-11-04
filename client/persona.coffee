# Using persona to log in.

$ =>

  # Return the e-mail of the currently logged in user (if any)
  # or `null`. This reads the 'S' cookie, which may in fact be an
  # invalid assertion. If that happens, a 'loginRequired' response
  # will be received on the first request to the server, which will
  # trigger persona login again.
  
  email = ->
    try 
      re      = /(?:(?:^|.*;\s*)S\s*\=\s*([^;]*).*$)|^.*$/ 
      cookie  = document.cookie.replace re, "$1"
      sess    = $.parseJSON unescape cookie
      sess.email || null
    catch err
      null

  # Shortcut for 'navigator.id'
   
  id = navigator.id

  # The login and logout buttons. Both should be hidden initially, and
  # will be displayed by `persona()`
   
  $i = $('#login').click -> id.request()
  $o = $('#logout').click -> id.logout()

  # Update the graphical aspects of persona integration: login/logout
  # buttons and (if not logged in) a login message.

  @persona = ->

    u = email()
    $o.toggle !u
    $i.toggle !!u

    $('#username').text(u || '')

    if !u
      $c.html ''
      new R($c)
        .open('div',{class:'alert alert-info login'})
        .open('strong').esc("You are not logged in.").close()
        .open('a',{class:'persona-button',href:'javascript:void(0)'},
          (r) -> r.$.click -> id.request())
        .open('span').esc('Login')
        .show()

  # Run persona. 
        
  id.watch
    loggedInuser: email()
    onlogin: (a) ->
      post 'login', {'assertion':a}, (r) ->
        do model
        do persona
        do route
    onlogout: ->
      doc.cookie = "S="
    onready: persona
    
