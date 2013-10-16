class Gallery

  maxHeight: 360
  maxWidth: 1024
  maxPending: 2

  constructor: (@$target,@gap=10) ->
    @width = @$target.width()
    @pictures = []
    @next = 0
    @onLargePicture = []
    @pending = 0

  addPicture: (picture) ->

    img = document.createElement 'img'

    pic =
      proof: picture
      started: false
      $img: $ img
    
    unfit = @pictures.length
    @pictures.push pic

    onload = =>
      --@pending
      pic.loaded = true
      pic.ratio = img.naturalWidth / (img.naturalHeight || 1)
      if img.naturalHeight > @maxHeight || img.naturalWidth > @maxWidth
        for f in @onLargePicture
          f pic, (url) ->
            $img = $('<img/>').attr('src', url).css
              width: img.width
              height: img.height
            $img.insertBefore pic.$img
            pic.$img.remove()
            pic.$img = $img
      @unfit unfit
      do @start

    img.crossOrigin = 'Anonymous' # To allow canvas.getDataURL
    img.onload = onload

    do @start

    null

  # Start loading a new image
  start: ->
    for picture in @pictures
      continue if picture.started
      return if @pending >= @maxPending
      picture.started = true
      picture.$img[0].src = picture.proof.thumb
      ++@pending
      
  # Get the optimum height starting at 'next' and grabbing as many
  # elements as possible. Returns the number of grabbed elements 
  fit: ->

    # if height is H, then the width of a picture is H * ratio,
    # so W = H * sum(ratios) + |pictures| * gap
    # so H = (W - |pictures| * gap) / sum(ratios)

    minHeight = 180
    oldHeight = 0
    oldCount  = 0
    count = 0
    sum = 0

    while true
      break if @pictures.length <= @next + count
      return null if !@pictures[@next + count].loaded  
      sum   += @pictures[@next + count].ratio
      count += 1
      height = (@width - @gap * count) / sum
      if height >= minHeight || oldHeight == 0
        oldHeight = height
        oldCount  = count 
      break if height < minHeight && oldHeight <= @maxHeight

    oldHeight = @maxHeight if oldHeight > @maxHeight
    return null if oldHeight == 0
    return [oldHeight,oldCount]

  # Unfit all elements after the specified one (including the last one's line)
  unfit: (pos) ->
    if @next >= pos
      $lines = @$target.children()
      next = 0
      for line in $lines
        $line = $ line
        images = $line.find('img').length
        if next + images >= pos
          $line.remove()
        else
          next += images
      @next = next
    do @fitAll
    
  # Repeatedly fit and render elements
  fitAll: -> 

    next = do @fit
    return if next == null

    count = next[1]
    height = next[0]

    $line = $('<div/>').css
      overflow: "hidden"
      height: height
      display: "none"
      marginBottom: @gap

    $line.appendTo @$target

    appearRandom = ($what) ->
      time = Math.random() * 500 + 500
      appear = -> $what.fadeIn 'fast'
      setTimeout appear, time

    while count-- > 0
      pic = @pictures[@next++]
      pic.$img.css
        float: "left"
        height: height
        width: height * pic.ratio
        marginRight: if count == 0 then 0 else @gap
      pic.$img.appendTo $line
      appearRandom $line
      
    do @fitAll    
