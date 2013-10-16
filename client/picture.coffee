# Uploading and displaying pictures

@Picture =

  # This function is called when a file is dropped on the window.
  onDropFile: null

  # Start uploading a file to an album
  upload: (file,album,next) -> 
    Upload.add
      done: 0
      size: 2
      run: (end) ->
        if !@uploader
          @uploader = Upload.send file, API.album.uploadUrl, { album: album }, (d) ->
            next d.id
          do end
        else    
          @uploader.wait (s) ->
            @done = s if s < @done
            do end

$ ->

  $b = $ 'body'

  @ondragover = ->
    if Picture.onDropFile != null
      $b.addClass 'drag' 
      false

  @ondragend = ->
    $b.removeClass 'drag'
    Picture.onDropFile == null

  @ondrop = (e) ->
    return if Picture.onDropFile == null
    do e.preventDefault
    Picture.onDropFile file for file in e.dataTransfer.files
    false
    
  Route.onChange.push -> Picture.onDropFile = null
  
