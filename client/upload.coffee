# Generic upload functions

@Upload =

  # A queue of tasks. Each task has a completion level. The queue is cleared once
  # all tasks are completed. 
  queue: []

  # Is the upload queue running ?
  isRunning: false

  # Returns the current progress, between 0 and 1
  currentProgress: ->
    total = 0
    done = 0
    for task in Upload.queue
      total += task.size
      done  += task.done
    return 1 if total == 0
    return done / total

  # Render the upload progress bar
  render: -> 
    $p = $ '#progress'
    if $p.length == 0
      $p = $ '<div id="progress" class="container" style="display:none">' +
        '<div class="progress progress-striped active">' +
        '<div class="progress-bar" role="progressbar"/></div></div>'
      $p.insertBefore('#container')
    p = Upload.currentProgress()
    if p == 1
      $p.hide 'fast'
    else
      $p.show 'fast'
      $p.find('.progress-bar').css({"width":(p*100).toFixed(2) + '%'})


  # Hide the progress bar
  hide: ->
    do $('#progress').hide

  # Add an item to the queue
  add: (task) ->
    Upload.queue.push task
    do Upload.run

  # Run a task in the queue, if possible. Calls itself again when it's over.
  run: ->
    return if Upload.isRunning
    do Upload.render
    Upload.isRunning = true
    for task in Upload.queue
      if task.done < task.size
        return task.run ->
          Upload.isRunning = false
          do Upload.run
    Upload.isRunning = false
    
  # Actually send data out. Returns an uploader object with a wait
  # method that waits for progress. During actual upload, progress
  # changes from 0 to 1. When the http response arrives, progress
  # moves to 2 and 'next' is called with the response from the server.
  send: (file, url, payload, next) -> 

    # The uploader object
    finished = false
    onProgress = []
    progress = (p) ->
      f p for f in onProgress
      onProgress = []

    uploader =
      wait: (next) ->
        return next 2 if finished
        onProgress.push next          

    # Build the request
    xhr = new XMLHttpRequest()
    xhr.open 'POST', url

    if 'upload' of xhr
      xhr.upload.onprogress = (e) ->
        if e.lengthComputable
          progress(e.loaded / e.total || 0)
                                      
    xhr.onload = ->
      finished = true
      progress 2

      text = xhr.responseText
      return API.error "Upload failed." if !text
      
      json = do ->
        try
          JSON.parse text
        catch error
          null
      return API.error "Upload failed." if !json
      return do API.loginRequest if json.requiresLogin
      return API.error json.error if json.error

      id = json.id
      return API.error "Upload failed." if !id
      next id 

    # Send the request
    flatten = (s) -> if typeof s == 'string' then s else JSON.stringify s
    fd = new FormData()
    fd.append 'file', file
    fd.append key, flatten value for key, value of payload
    xhr.send fd

    # Return the uploader
    uploader  
        
$ ->
  API.onFailure.push Upload.hide
  
