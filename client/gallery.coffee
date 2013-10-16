class Gallery

  pictures: []
  next: 0

  constructor: (@$target,@gap=10) ->
    @width = @$target.width()
    
  addPicture: (url) ->

    img = document.createElement 'img'

    pic =
      $img: $ img
    
    @pictures.push pic
    
    onload = =>
      pic.loaded = true
      pic.ratio = img.naturalWidth / (img.naturalHeight || 1)
      do @fitAll

    img.onload = onload

    img.src = url

    null

  # Get the optimum height starting at 'next' and grabbing as many
  # elements as possible. Returns the number of grabbed elements 
  fit: ->

    # if height is H, then the width of a picture is H * ratio,
    # so W = H * sum(ratios) + |pictures| * gap
    # so H = (W - |pictures| * gap) / sum(ratios)

    minHeight = 180
    maxHeight = 360
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
      break if height < minHeight && oldHeight <= maxHeight

    oldHeight = maxHeight if oldHeight > maxHeight
    return null if oldHeight == 0
    return [oldHeight,oldCount]

  # Repeatedly fit and render elements
  fitAll: -> 

    next = do @fit
    return if next == null

    count = next[1]
    height = next[0]

    $line = $('<div/>').css
      overflow: "hidden"
      height: height
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
        display: "none"
        marginRight: if count == 0 then 0 else @gap
      pic.$img.appendTo $line
      appearRandom pic.$img
      
    do @fitAll    
