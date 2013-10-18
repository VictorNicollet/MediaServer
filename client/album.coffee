# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ==============================================================================
  # Model functions

  # Is the user an administrator ?
  isAdmin = false

  # A cache of all album proofs by identifier
  albumById = {}

  # Contents of each album, by identifier, with expiration date
  albumPicturesById = {}

  # Load all albums
  loadAll = (next) ->
    API.album.all (list,admin) ->
      isAdmin = admin
      albumById[album.id.id] = album for album in list        
      next list

  # Create a new album and returns its id and proof.
  create = (name,next) ->
    API.album.create name, (album) ->
      albumById[album.id.id] = album
      next album

  # Get an album by identifier. Return null if not available.
  get = (id,next,reload=true) ->
    if id of albumById
      album = albumById[id]
      now = (new Date).toISOString()
      return next album if now < album.id.expires
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
      API.album.pictures album.id, (contents) -> 
        now = new Date()
        contents.expires = new Date(+now + 1000 * 600) # 10 minutes
        albumPicturesById[id] = contents
        next contents

  # Update the cached version of a picture based on results from the server
  updateCachedPicture = (album, picture) ->
    id = album.id.id
    if id of albumPicturesById && albumPicturesById.expires > +(new Date())
      albumPictures = albumPicturesById[id]
      i = 0
      while i < albumPictures.pictures.length
        if albumPictures.pictures[i].picture == picture.picture
          return albumPictures.pictures[i] = picture
      albumPictures.pictures.push picture

  # Save access sharing
  saveAccess = (access, next) ->
    API.album.share access, next
      
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

    API.album.setThumbnail album.id, picture.picture, base64, (newPicture) ->
      updateCachedPicture album.id, newPicture.picture
      next newPicture.picture  

  # ==============================================================================
  # Controller functions
  $ ->

    # Display the list of albums
    Route.register "/", (args,render) ->
      $page = $ "<table class='table'/>"

      $head = $ "<thead><tr><td><h2>Albums</h2></tr></td><thead>"
      $head.appendTo $page

      $list = $ "<tbody/>"      
      $list.appendTo $page
      loadAll (list) ->

        for album in list
          $link = $ "<tr><td><a/></td></tr>"
          $link.find("a").attr("href","/album/"+album.id.id).text(album.name)
          $link.appendTo $list
          if isAdmin
            count = album.get.length + album.put.length
            share = if count == 0 then "" else
              if count == 1 then "Shared with 1 person" else "Shared with #{count} people"
            $shared = $('<span class="text-muted pull-right"/>').text share
            $shared.appendTo $link.find 'td'                
      
        if isAdmin

          # New album button
          $new = $ "<button type='button' class='btn btn-success btn-sm pull-right'>New album</button>"
          $new.insertBefore $page.find 'thead h2'
          $new.click ->
            name = prompt "Name of the new album"
            if name
              create name, (album) ->
                Route.go("/album/" + album.id.id)

          # Share albums button
          $share = $ "<button type='button' class='btn btn-default btn-sm pull-right'>Share</button>"
          $share.insertBefore $page.find 'thead h2'
          $share.css('marginRight', 10).click ->
            Route.go "/albums/share"
          
      render $page

    # Display the album sharing page
    Route.register "/albums/share", (args,render) ->
      $form = $ "<form role='form'/>"

      loadAll (list) ->
        for album in list

          continue if !isAdmin

          $group = $ '<div class="form-group"/>'

          $label = $('<label/>').attr({for:"share-"+album.id.id}).text(album.name)
          $label.appendTo $group
          
          shared = album.get.concat album.put
          $field = $('<textarea class="form-control"/>').val(shared.join "; ").attr
            id: "share-" + album.id.id
            name: album.id.id
            placeholder: 'name@domain.com; name@domain.com'
          $field.appendTo $group

          $group.appendTo $form

        $("<button type='submit' class='btn btn-primary'>Save</button>").appendTo $form

      $form.submit ->

        $form.find('button').attr "disabled", true

        access = {}
        $form.find('textarea').each ->
          access[$(@).attr 'name'] = $(@).val().split(';')

        saveAccess access, -> Route.go '/'

        false
          
      render $form
      
    # Display the contents of an album
    Route.register "/album/*", (args,render) -> 
      get args[0], (album) ->

        $page = $ '<div/>'

        $name = $('<h3/>').text(album.name)
        $name.appendTo $page

        if album.id.access == 'PUT'
          $name.before '<p class="pull-right text-muted">Drop pictures here to upload them</p>'
          Picture.onDropFile = (f) ->
            getAlbum = (next) -> get(album.id.id,next)
            Picture.upload f, getAlbum, (id) ->

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

        getPictures album.id.id, (pics) ->

          if pics.pictures.length == 0

            $page.append("<div id=empty class='well empty'>No pictures in this album</div>")

          else

            gal = getTheGallery()              
            for picture in pics.pictures
              gal.addPicture picture

          Picture.onUploadFinished.push (album2,picture) ->
            return if album2.id.id != album.id.id
            gal = getTheGallery()
            gal.addPicture picture
                      
        render $page
