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
      API.startSession a, paint
    onlogout: () ->
      API.closeSession paint
    onready: paint
  
