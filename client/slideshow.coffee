class Slideshow

  constructor: (pics,@c = 0,@gap = 10) ->

    # Display animation versioning
    @v = 0

    # All pictures displayed in this slideshow
    @pics = pics
    
    # Root object
    @$ = $ '#slideshow'
    if @$.length == 0
      @$ = $('<div id=slideshow/>').appendTo('body')
      @$.click (e) =>
        if e.target == @$[0] || $(e.target).is('img')
          @$.remove()
          
      $('<a id=slideshow-prev href="javascript:void(0)"><span>&lt;</span></a>').appendTo(@$).click =>
        @display(@c - 1) if @c > 0 

      $('<a id=slideshow-next href="javascript:void(0)"><span>&gt;</span></a>').appendTo(@$).click =>
        @display(@c + 1) if @c < @pics.length - 1 
  
    @display @c

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
        @$c.remove() if @$c
        @$c = $item
      else
        $item.remove()

    if @$c
      @$c.fadeOut 'fast', show        
    else
      do show
    
  # Display a loading message

  load: ->
    $l = $('<div class=gallery-loading>Loading...</div>').appendTo(@$).hide()
    @center $l

  # Precache picture `i` in the list.

  precache: (i) ->

    pic = @pics[i]
    img = document.createElement('img')
    img.onload = -> $(img).remove()
    img.src = pic.url
    $(img).appendTo(@$).hide()

  # Display picture `i` in the list.
    
  display: (i) ->

    do @load

    # Index of currently displayed picture.
    @c = i
    
    pic = @pics[i]
    img = document.createElement('img')
    img.onload = =>
      
      # Resize image to fit on screen
      w = img.naturalWidth
      h = img.naturalHeight
      @center $(img), w, h

      # Precache previous and next images, for
      # higher performance
      @precache(i-1) if i > 0 
      @precache(i+1) if i < @pics.length - 1
      
    img.src = pic.url
    $(img).appendTo(@$).hide()
      
$ ->
  Route.onChange.push ->
    $('#slideshow').remove()
