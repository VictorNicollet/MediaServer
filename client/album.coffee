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

  # Update the cached version of a picture based on results from the server
  updateCachedPicture = (album, picture) ->
    id = album.album
    if id of albumPicturesById && albumPicturesById.expires > +(new Date())
      albumPictures = albumPicturesById[id]
      i = 0
      while i < albumPictures.pictures.length
        if albumPictures.pictures[i].picture == picture.picture
          return albumPictures.pictures[i] = picture
      albumPictures.pictures.push picture
  
  # Resize an image, send the thumbnail to the server
  resize = (img,picture,album,next) ->

    maxH = Gallery.prototype.maxHeight
    maxW = Gallery.prototype.maxWidth
    w = img.naturalWidth
    h = img.naturalHeight
    ratio = w / h
    if w > maxW
      w = maxW
      h = w / ratio
    if h > maxH
      h = maxH
      w = h * ratio

    canvas = $('<canvas>')[0]
    canvas.width  = w
    canvas.height = h
    ctx = canvas.getContext '2d'
    ctx.drawImage img, 0, 0, w, h
    base64 = canvas.toDataURL('image/jpeg').substring 'data:image/jpeg;base64,'.length 

    API.album.setThumbnail album, picture.picture, base64, (newPicture) ->
      updateCachedPicture album.album, newPicture.picture
      next newPicture.picture  

  # ==============================================================================
  # Controller functions
  $ ->

    # Display the list of albums
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
        isAdmin = false
        for album in list
          $link = $ "<tr><td><a/></td></tr>"
          $link.find("a").attr("href","/album/"+album.album).text(album.name)
          $link.appendTo $list
          isAdmin = album.access == "OWN" || isAdmin
        if isAdmin
          $share = $ "<button type='button' class='btn btn-default btn-sm pull-right'>Share</button>"
          $share.insertAfter $page.find 'thead button:last'
          $share.css('marginRight', 10).click ->
            Route.go "/albums/share"
          
      render $page

    # Display the album sharing page
    Route.register "/albums/share", (args,render) ->
      $form = $ "<form role='form'/>"

      loadAll (list) ->
        for album in list
          continue if album.access != "OWN"

          $group = $ '<div class="form-group"/>'

          $label = $('<label/>').attr({for:album.id}).text(album.name)
          $label.appendTo $group
          
          shared = album.get.concat album.put
          $field = $('<textarea class="form-control"/>').val(shared.join "; ").attr
            id: album.id
            name: album.id
            placeholder: 'name@domain.com; name@domain.com'
          $field.appendTo $group


          $group.appendTo $form

        $("<button type='submit' class='btn btn-primary'>Save</button>").appendTo $form
        
      render $form
      
    # Display the contents of an album
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

        getTheGallery = ->
          $('#empty').remove() 
          $t = $('#gallery')
          if $t.length == 0
            $t = $("<div id=gallery class='row'/>").appendTo $page
            gal = new Gallery($t)
            gal.onLargePicture.push (pic,setUrl) ->
              resize pic.$img[0], pic.proof, album, (result) ->
                setUrl result.thumb
            $t.data 'gallery', gal    
            gal
          else
            $t.data 'gallery'

        getPictures album.album, (pics) ->

          if pics.pictures.length == 0

            $page.append("<div id=empty class='well empty'>No pictures in this album</div>")

          else

            gal = getTheGallery()              
            for picture in pics.pictures
              gal.addPicture picture

          Picture.onUploadFinished.push (album2,picture) ->
            return if album2.album != album.album
            gal = getTheGallery()
            gal.addPicture picture
                      
        render $page
