class Slideshow

  constructor: (pics,@gap = 10) ->

    @v = 0

    @$ = $ '#slideshow'
    if @$.length == 0
      @$ = $('<div id=slideshow/>').appendTo('body')
      @$.click (e) =>
        if e.target == @$[0] || $(e.target).is('img')
          @$.remove()

    @pics = pics

    @display 0

  # Display an item centered in the middle of the screen.

  center: ($item,w=null,h=null) ->

    v = ++@v;
    
    w = $item.width() if !w
    h = $item.height() if !h

    r = w / (h || 1)
    ph = @$.height() - 2 * @gap
    pw = @$.width() - 2 * @gap
    if w > pw
      w = pw
      h = w / r
    if h > ph
      h = ph
      w = h * r

    y = (ph - h) / 2 + @gap
    x = (pw - w) / 2 + @gap

    show = =>
      if v == @v
        $item.css({position:'absolute',left:x,top:y,width:w,height:h}).fadeIn('fast')
        @$c = $item

    if @$c && @$c.is(':visible')
      @$c.fadeOut 'fast', show    
    else
      do show
    
  # Display a loading message

  load: ->
    $l = $('<div class=gallery-loading>Loading...</div>').appendTo(@$).hide()
    @center $l

  # Display picture `i` in the list.
    
  display: (i) ->

    do @load
    
    pic = @pics[i]
    img = document.createElement('img')
    img.onload = =>
      
      # Resize image to fit on screen
      w = img.naturalWidth
      h = img.naturalHeight
      @center $(img), w, h 
      
    img.src = pic.url
    $(img).appendTo(@$).hide()
      
$ ->
  Route.onChange.push ->
    $('#slideshow').remove()
