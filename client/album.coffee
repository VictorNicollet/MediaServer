# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ================================================================================
  # Model functions

  # All available albums
  allCache = null
  allCacheTime = null
  
  # Create a new album. Clears the album list. Returns the id of the
  # created album
  create = (name,next) ->
    API.album.create name, (id) ->
      allCache = null
      next id

  # ================================================================================
  # Controller functions
  $ ->

    Route.register "/", (args,render) ->
      $newAlbum = $ "<button type='button' class='button'>New album</button>"
      $newAlbum.click ->
        name = prompt "Name of the new album"
        if name
          create name, (id) ->
            Route.go("/album/" + id)
      render $newAlbum

    Route.register "/album/*", (args,render) -> 
      render args[0]
