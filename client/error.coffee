$ ->
  
  API.onError = (text) ->
    do $('#error').remove

    # Create new error and prepend it to container
    $e = $('<div id="error" class="alert alert-danger alert-dismissable"></div>').text text
    $e.prependTo '#container'

    # Create and plug dismissal button
    $d = $('<button type="button" class="close" data-dismiss="alert" aria-hidden="true">&times;</button>').click ->
      do $e.remove
    $d.appendTo $e

