# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ==============================================================================
  # Model functions

  # A cache of all album proofs by identifier
  albumById = {}

  # Load all albums
  loadAll = (next) ->
    API.album.all (list) ->
      albumById[album.album] = album for album in list        
      next list

  # Create a new album and returns its id and proof.
  create = (name,next) ->
    API.album.create name, (album) ->
      albumById[album.album] = album
      next album

  # ==============================================================================
  # Controller functions
  $ ->

    Route.register "/", (args,render) ->
      $page = $ "<table class='table'/>"

      $newAlbum = $ "<thead><tr><td><button type='button' class='btn btn-success btn-xs pull-right'>New album</button></tr></td><thead>"
      $newAlbum.appendTo $page
      $newAlbum.find("button").click ->
        name = prompt "Name of the new album"
        if name
          create name, (album) ->
            Route.go("/album/" + album.album)

      $list = $ "<tbody/>"      
      $list.appendTo $page
      loadAll (list) ->
        for album in list
          $link = $ "<tr><td><a/></td></tr>"
          $link.find("a").attr("href","/album/"+album.album).text(album.name)
          $link.appendTo $list
          
      render $page

    Route.register "/album/*", (args,render) -> 
      render args[0]
