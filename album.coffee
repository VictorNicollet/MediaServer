require 'coffee-script'
store = require './store'
api = require './api'
proof = require './proof'

# You cannot have more than this number of albums
maxAlbums = 50

# You cannot have more than this number of pictures in an album
maxPictures = 250

# The global list of albums
defaultAlbums = ->
  admins: [ "victor@nicollet.net", "alix.marcorelles@gmail.com" ]
  contacts: []
  albums: []

# Get the "next id" on a list of albums: the identifier of the next
# album to be added
nextId = (albums) ->
  id = 0
  for album in albums.albums
    id = album.id + 1 if album.id >= id
  id

# Create a brand new album inside the specified album set
makeAlbum = (albums,name) ->
  name: name
  get: []
  put: []
  id: nextId albums

# Is a given email the administrator of an album set ?
isAdmin = (albums,email) ->
  albums.admins.indexOf(email) != -1

# Grab all visible albums for a given user
grabVisibleAlbums = (albums,email,list=null) ->
  list = list || albums.albums
  grab = (album) ->
    out = 
      name: album.name || "Untitled"
      album: album.id
      access:
        if admin then 'PUT' else
          if album.put.indexOf(emailId) != -1 then 'PUT' else
           if album.get.indexOf(emailId) != -1 then 'GET' else ''
    if isAdmin
      out.get = (albums.contacts[i] for i in album.get)
      out.put = (albums.contacts[i] for i in album.put)
    out
  admin = isAdmin albums, email
  emailId = albums.contacts.indexOf email
  grabbed = (grab album for album in list)
  (proof.make album for album in grabbed when album.access)

# The default piclist
defaultPiclist = ->
  pics: []
  thumbs: []

# Get a signed picture
getSignedPicture = (album,piclist,i) ->

  url = store.getUrl S3Key.original album, piclist.pics[i]
  thumb = url
  if piclist.thumbs[i] != null
    thumb = store.getUrl S3Key.thumb album, piclist.thumbs[i]

  obj =
    picture: piclist.pics[i]
    url: url
    thumb: thumb

  proof.make obj 


# The S3 keys
S3Key =
  albums: "albums.json"
  album: (album) -> "album-#{album.album}.json"
  originalPrefix: (album) -> "album/#{album.album}/original"
  original: (album,md5) -> "album/#{album.album}/original/#{md5}"
  thumbPrefix: (album) -> "album/#{album.album}/thumb"
  thumb: (album,md5) -> "album/#{album.album}/thumb/#{md5}"
        
module.exports.install = (app,next) ->

  # Return the list of all available albums
  api.get app, 'albums', (req, fail, json) ->
    albums = store.getJSON S3Key.albums, (err,albums) ->
      return fail err if err
      albums = albums || defaultAlbums()
      json
        admin: isAdmin albums, req.email
        albums: grabVisibleAlbums albums, req.email 

  # Set the access level for albums
  api.post app, 'albums/share', (req, fail, json) ->
    update = (albums,next) ->

      console.log req.body
                  
      albums = albums || defaultAlbums()
      if !isAdmin albums, req.email
        return next "Only admins can share albums", null

      emails = []
      emailPos = (email) ->

        email = email.trim()
        return null if !email
        
        return null if isAdmin albums, email

        idx = emails.indexOf email
        return idx if idx != -1

        emails.push email
        emails.length - 1
        
      for album in albums.albums
        shares = req.body[album.id] || []
        album.put = []
        album.get = (pos for pos in (emailPos email for email in shares) when pos != null)

      albums.contacts = emails

      console.log albums

      next null, albums

    store.updateJSON S3Key.albums, update, (err) ->
      return fail err if err
      json { success: true }

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->
    album = null
    update = (albums,next) ->
      albums = albums || defaultAlbums()
      if !isAdmin albums, req.email
        return next "Only admins can create albums", null
      if albums.albums.length == maxAlbums
        return next "Maximum number of albums reached", null
      name = req.body.name || "Untitled"
      album = makeAlbum albums, name
      albums.albums.push album
      album = grabVisibleAlbums albums, req.email, [album]
      next null, albums
    store.updateJSON S3Key.albums, update, (err) -> 
      return fail err if err
      json { album: album[0] }

  # Return the list of all pictures in an album
  api.post app, 'album/pictures', (req, fail, json) ->

    album = req.body.album
    if !album || !proof.check album
      return fail "Invalid album signature."

    store.getJSON S3Key.album(album), (err,data) ->
      return fail err if err

      data = data || defaultPiclist()
      pictures = (getSignedPicture album, data, i for pic, i in data.pics)
      
      json { pictures: pictures }

  # Uploading a thumbnail
  api.post app, 'album/thumbnail', (req, fail, json) ->

    album = req.body.album
    if !album || !proof.check album || (album.access != "OWN" && album.access != "PUT") 
      return fail "Invalid album signature." 

    thumb = do ->
      try
        new Buffer req.body.thumb, 'base64'
      catch error
        null
         
    if !thumb
      return fail "Missing or invalid thumbnail."

    id = req.body.picture
    if !id
      return fail "Missing picture."

    newPicture = null

    file =
      type: "image/jpeg"
      name: "thumb.jpg"
      content: thumb

    store.uploadFileFromString S3Key.thumbPrefix(album), file, (err,id2) -> 
      return fail err if err

      update = (piclist,next) ->
        piclist = piclist || defaultPiclist()
        pos = piclist.pics.indexOf id
        return next "Picture not found in album.", null if pos == -1
        piclist.thumbs[pos] = id2
        newPicture = getSignedPicture album, piclist, pos
        next null, piclist

      store.updateJSON S3Key.album(album), update, (err) ->
        return fail err if err
        json { picture: newPicture }
   

  # Uploading a file
  api.post app, 'album/upload', (req, fail, json) ->

    file = req.files.file
    if !file
      return fail "No picture provided."

    album = do ->
      try
        JSON.parse req.body.album
      catch error
        null
      
    if !album || !proof.check album || (album.access != "OWN" && album.access != "PUT") 
      return fail "Invalid album signature." 

    store.uploadFile S3Key.originalPrefix(album), file, (err,id) ->

      return fail err if err

      thePicture = null

      update = (piclist,next) ->
        piclist = piclist || defaultPiclist()
        pos = piclist.pics.indexOf id
        return next null, piclist if pos != -1
        piclist.thumbs.push null
        piclist.pics.push id
        thePicture = getSignedPicture album, piclist, piclist.pics.length - 1
        next null, piclist
        
      store.updateJSON S3Key.album(album), update, (err) ->
        return fail err if err
        json { picture: thePicture }
      
  do next
