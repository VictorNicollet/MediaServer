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
    
