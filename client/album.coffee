# The album model deals with individual albums, as well as the list of
# all albums the user can see

do ->

  # ==============================================================================
  # Model functions

  # Is the user an administrator ?
  # This is a question asked so frequently that it's worth storing it here.
  # The value will be set after calling `loadAll`.

  isAdmin = false

  # The model stores elementary information about albums, such as the name.
  # It also stores model identifiers (along with their proofs). 

  albumById = {}

  cache = (a) -> albumById[a.id.id] = a

  # This cache stores album pictures. However, it only caches a single album's
  # contents at any given time.

  picsById = {}

  cachePics = (id,pictures) ->
    picsById = {}
    picsById[id] = pictures

  getCachedPics = (id) ->
    if id of picsById then picsById[id] else null

  appendCachedPic = (id,picture) -> 
    if id of picsById
      picsById[id].push picture
      
  # Loads or reloads all albums. Also determines whether the user is an
  # administrator.
   
  loadAll = (next) ->
    API.requests.start (end) ->
      API.get "albums", {}, (r) ->
        isAdmin = r.admin          
        cache album for album in r.albums        
        next r.albums
        do end

  # Grabs an album by its identifier. Does not care about cache freshess:
  # an album in cache will always be returned. Returns null if no album
  # is found.

  get = (id,next,reload=true) ->
    if id of albumById
      next albumById[id]
    else if reload 
      loadAll -> get id, next, false
    else
      next null

  # Grabs an album's identifier along with a proof. If the proof
  # is expired, queries the server for a fresh proof. 
  
  getProof = (id,next,reload=true) ->
    
    if id of albumById
      album = albumById[id]
      now = (new Date).toISOString()
      return next album.id if now < album.id.expires

    if reload
      loadAll -> getProof id, next, false
    else
      next null
      
  # Create a new album. Returns a cache-able album object.
   
  create = (name,next) ->
    API.requests.start (end) ->
      API.post "album/create", { name: name }, (r) ->
        next cache r.album        
        do end

  # Get the contents of an album. This query is not cached.
  # Returned object contains:
   
  getPictures = (id,next) ->
    getProof id, (id) ->
      API.requests.start (end) ->
        API.post "album/pictures", { album: id }, (r) ->
          next cachePics id.id, r.pictures
          do end

  # Save access sharing
  
  share = (access, next) ->
    API.requests.start (end) ->
      API.post "albums/share", access, ->
        do next
        do end
      
  # Resize an image, send the thumbnail to the server, return the new
  # picture, or null if failed.
  # 
  # The user should have 'put' access to do so. 
  
  resize = (img,picture,album,next) ->

    return next null if album.id.access != 'PUT'

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

    API.requests.start (end) ->
      getProof album.id.id, (id) ->
        return do end if id == null 
        payload = { album: id, picture: picture.id, thumb: base64 }
        API.post "album/thumbnail", payload, (r) ->
          next r.picture
          do end

  # ==============================================================================
  # Controller functions
  $ ->

    # Display the list of albums
    Route.register "/", (args,render) ->
      $page = $ "<table class='table album'/>"

      $head = $ "<thead><tr><td colspan=3><h2>Albums</h2></tr></td><thead>"
      $head.appendTo $page

      $list = $ "<tbody/>"      
      $list.appendTo $page
      loadAll (list) ->

        for album in list

          $link = $ "<tr><td><a/></td></tr>"
          $link.find("a").attr("href","/album/"+album.id.id).text(album.name)
          $link.appendTo $list

          $shared = $('<td class=text-muted/>').appendTo $link
          if isAdmin
            count = album.get.length + album.put.length
            if count > 0
              share = if count == 1 then "Shared with 1 person" else "Shared with #{count} people"
              $shared.text share

          $size = $('<td class=rowsize>').prependTo $link
          $('<span/>').text(album.size || '').appendTo $size

          if album.thumb != null
            $('<img/>').attr('src',album.thumb).appendTo $link.find 'a'
      
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
          id = album.id.id

          $group = $ '<div class="form-group"/>'

          $label = $('<label/>').attr({for:"share-"+id}).text(album.name)
          $label.appendTo $group
          
          shared = album.get.concat album.put
          $field = $('<textarea class="form-control"/>').val(shared.join "; ").attr
            id: "share-" + id
            name: id
            placeholder: 'name@domain.com; name@domain.com'
          $field.appendTo $group

          $group.appendTo $form

        $("<button type='submit' class='btn btn-primary'>Save</button>").appendTo $form

      $form.submit ->

        $form.find('button').attr "disabled", true

        access = {}
        $form.find('textarea').each ->
          access[$(@).attr 'name'] = $(@).val().split /[\n\r\t ;,]/

        share access, -> Route.go '/'

        false
          
      render $form
      
    # Display the contents of an album
    Route.register "/album/*", (args,render) ->

      id = args[0]      
      get id, (album) ->

        $page = $ '<div/>'

        $name = $('<h3/>').text(album.name)
        $name.appendTo $page

        if album.id.access == 'PUT'
          $name.before '<p class="pull-right text-muted">Drop pictures here to upload them</p>'
          Picture.onDropFile = (f) ->
            getAlbum = (next) -> getProof(id,next)
            Picture.upload f, getAlbum, ->

        # This function returns the full-page gallery (and creates it, if missing).

        getTheGallery = ->
          
          $('#empty').remove() 
          $t = $('#gallery')

          if $t.length == 0

            $t = $("<div id=gallery class='row'/>").appendTo $page

            gal = new Gallery($t)
            gal.onLargePicture.push (pic,setUrl) ->
              resize pic.$i[0], pic.data, album, (r) ->
                setUrl r.thumb if r != null

            gal.wrap = (p,i) ->
              $('<a href="javascript:void(0)"/>').click ->                               
                new Slideshow getCachedPics(id), i 

            $t.data 'gallery', gal    
            gal
            
          else

            $t.data 'gallery'

        # Grab all pictures and add them to the gallery.

        getPictures id, (pics) ->

          if pics.length == 0

            $page.append("<div id=empty class='well empty'>No pictures in this album</div>")

          else

            gal = getTheGallery()              
            for picture in pics
              gal.addPicture picture

          Picture.onUploadFinished.push (id2,picture) ->
            return if id2.toString() != id
            appendCachedPic id, picture
            gal = getTheGallery()
            gal.addPicture picture
                      
        render $page
