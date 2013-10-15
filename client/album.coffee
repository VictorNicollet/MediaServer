# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ==============================================================================
  # Model functions

  # Load all albums
  loadAll = (next) ->
    API.album.all next

  # Create a new album and returns its id and proof.
  create = (name,next) ->
    API.album.create name, next

  # ==============================================================================
  # Controller functions
  $ ->

    Route.register "/", (args,render) ->
      $page = $ "<div/>"

      $newAlbum = $ "<button type='button' class='button'>New album</button>"
      $newAlbum.appendTo $page
      $newAlbum.click ->
        name = prompt "Name of the new album"
        if name
          create name, (album) ->
            Route.go("/album/" + album)

      $list = $ "<table class='table'/>"      
      $list.appendTo $page
      loadAll (list) ->
        for album in list
          $link = $ "<tr><td><a/></td></tr>"
          $link.find("a").attr("href","/album/"+album.id).text(album.name)
          $link.appendTo $list
          
      render $page

    Route.register "/album/*", (args,render) -> 
      render args[0]
