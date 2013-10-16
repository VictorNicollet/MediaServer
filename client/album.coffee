# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ==============================================================================
  # Model functions

  # A cache of all album proofs by identifier
  albumById = {}

  # Contents of each album, by identifier, with expiration date
  albumPicturesById = {}

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

  # Get an album by identifier. Return null if not available.
  get = (id,next,reload=true) ->
    if id of albumById
      album = albumById[id]
      now = (new Date).toISOString()
      return next album if now < album.expires
      return next null if !reload
      loadAll ->
        get id, next, false
    else
      return next null if !reload
      loadAll ->
        get id, next, false

  # Get the contents of an album
  getPictures = (id,next) ->
    if id of albumPicturesById && albumPicturesById.expires > +(new Date())
      next albumPicturesById[id]
    get id, (album) ->
      API.album.pictures album, (contents) -> 
        now = new Date()
        contents.expires = new Date(+now + 1000 * 600) # 10 minutes
        albumPicturesById[id] = contents
        next contents

  # ==============================================================================
  # Controller functions
  $ ->

    Route.register "/", (args,render) ->
      $page = $ "<table class='table'/>"

      $newAlbum = $ "<thead><tr><td><button type='button' class='btn btn-success btn-sm pull-right'>New album</button><h2>Albums</h2></tr></td><thead>"
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
      get args[0], (album) ->

        $page = $ '<div/>'

        $name = $('<h3/>').text(album.name)
        $name.appendTo $page

        if album.access == 'OWN' || album.access == 'PUT'
          $name.before '<p class="pull-right text-muted">Drop pictures here to upload them</p>'
          Picture.onDropFile = (f) ->
            Picture.upload f, album, (id) ->
              console.log "File uploaded: %s = %o", id, f 

        getPictures album.album, (pics) ->
          if pics.pictures.length == 0
            $page.append("<div class='well empty'>No pictures in this album</div>")
          else
            for picture in pics.pictures
              $page.append($("<div/>").text(picture.picture))
              
        render $page
