# Persona interaction

@Persona =

  request: ->

    $('#container').html ''

    $well = $ "<div class='alert alert-info login'><strong>You are not logged in.</strong></div>"
    $well.appendTo('#container')
        
    $b = $ '<a class="persona-button" href="javascript:void(0)"><span>Login</span></a>'
    $b.appendTo $well
    $b.click ->
      do navigator.id.request


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
      do Route.dispatch
    onlogout: () ->
      API.session.close paint
    onready: paint
  
