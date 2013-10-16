# Uploading and displaying pictures

@Picture =

  # This function is called when a file is dropped on the window.
  onDropFile: null

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
  
