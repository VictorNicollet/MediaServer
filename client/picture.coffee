# Uploading and displaying pictures

@Picture =

  # This function is called when a file is dropped on the window.
  onDropFile: null

  # These functions are called when a file finishes uploading, with the
  # album and the new picture
  onUploadFinished: []

  # Start uploading a file to an album
  upload: (file,album,next) -> 
    Upload.add
      done: 0
      size: 2
      run: (end) ->
        if !@uploader
          @uploader = Upload.send file, API.album.uploadUrl, { album: album }, (d) ->
            console.log d
            next d.picture.picture
            for f in Picture.onUploadFinished
              f album, d.picture
          do end
        else    
          @uploader.wait (s) =>
            @done = s if s > @done
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
    files = e.dataTransfer.files
    files.sort (a,b) ->
      return -1 if a.lastModifiedDate < b.lastModifiedDate
      return  1 if a.lastModifiedDate > b.lastModifiedDate
      return  0
    Picture.onDropFile file for file in files
    false
    
  Route.onChange.push ->
    Picture.onDropFile = null
    Picture.onUploadFinished = []
