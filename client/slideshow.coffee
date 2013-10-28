class Slideshow

  constructor: (pics) ->

    @$ = $ '#slideshow'
    if @$.length == 0
      @$ = $('<div id=slideshow/>').appendTo('body')
      @$.click (e) =>
        if e.target == @$[0]
          @$.remove()

    @pics = pics

    @display 0

  display: (i) ->
    pic = @pics[i]
    img = document.createElement('img')
    img.onload = ->
      $(img).show()
    img.src = pic.url
    $(img).appendTo(@$).hide()
      
$ ->
  Route.onChange.push ->
    $('#slideshow').remove()
