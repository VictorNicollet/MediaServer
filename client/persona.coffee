# Persona interaction
$ ->
  
  $in = $ '#login'
  $in.click ->
    do navigator.id.request

  $out = $ '#logout'
  $out.click ->
    do navigator.id.logout

  $u = $ '#username'
  navigator.id.watch
    loggedInUser: API.getUserEmail()
    onlogin: (assertion) ->
      do $in.hide
      do $out.show
      $u.text API.getUserEmail()
    onlogout: () ->
      do API.closeSession
      do $out.hide
      do $in.show
      $u.text ""
    onready: () ->
      u = API.getUserEmail()
      if u == null
        do $out.show
      else
        do $in.show
        $u.text u
  
