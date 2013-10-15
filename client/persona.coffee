# Persona interaction
$ ->
  
  $in = $ '#login'
  $in.click ->
    do navigator.id.request

  $out = $ '#logout'
  $out.click ->
    do navigator.id.logout

  paint = ->
    u = API.getUserEmail()
    $in.toggle(u == null)
    $out.toggle(u != null)
    $('#username').text(u || '')

  $u = $ '#username'
  navigator.id.watch
    loggedInUser: API.getUserEmail()
    onlogin: (a) ->
      API.session.start a, paint
    onlogout: () ->
      API.session.close paint
    onready: paint
  
