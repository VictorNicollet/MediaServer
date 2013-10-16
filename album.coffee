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
  albums.admins.indexOf email != -1

# Grab all visible albums for a given user
grabVisibleAlbums = (albums,email) -> 
  grab = (album) ->
    name: album.name || "Untitled"
    album: album.id
    access:
      if admin then 'OWN' else
        if album.put.indexOf emailId != -1 then 'PUT' else
          if album.get.indexOf emailId != -1 then 'GET' else ''
  admin = isAdmin albums, email
  emailId = albums.contacts.indexOf email
  grabbed = (grab album for album in albums.albums)
  (proof.make album for album in grabbed when album.access)

# The default piclist
defaultPiclist = ->
  pics: []
  noThumb: [] 

# The S3 keys
S3Key =
  albums: "albums.json"
  album: (album) -> "album-#{album.album}.json"
  
module.exports.install = (app,next) ->

  # Return the list of all available albums
  api.get app, 'albums', (req, fail, json) ->
    albums = store.getJSON S3Key.albums, (err,albums) ->
      return fail err if err
      json { albums: grabVisibleAlbums albums, req.email }

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->
    album = null
    update = (albums,next) ->
      albums = albums || defaultAlbums()
      if !isAdmin albums, req.email
        return next "Only admins can create albums", null
      if albums.length == maxAlbums
        return next "Maximum number of albums reached", null
      name = req.body.name || "Untitled"
      album = makeAlbum albums, name
      albums.albums.push album
      next null, albums
    store.updateJSON S3Keys.albums, update, (err) -> 
      return fail err if err
      json { album: album }

  # Return the list of all pictures in an album
  api.post app, 'album/pictures', (req, fail, json) ->

    album = req.body.album
    if !album || !proof.check album
      return fail "Invalid album signature."

    store.getJSON S3Key.album(album), (err,data) ->
      return fail err if err

      data = data || defaultPiclist()

      signed = (pic,data) ->
        obj =
          picture: pic
          thumb: data.noThumb.indexOf pic == -1
        proof.make obj 

      pictures = (signed pic, data for pic in data.pics)
      
      json { pictures: pictures }

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

    store.uploadFile "album/#{album.album}/original", file, (err,id) ->

      return fail err if err

      update = (piclist,next) ->
        piclist = piclist || defaultPiclist()
        pos = piclist.pics.indexOf id
        return next null, piclist if pos != -1
        piclist.noThumb.push piclist.pics.length
        piclist.pics.push id
        next null, piclist
        
      store.updateJSON S3Key.album(album), update, (err) ->
        return fail err if err
        json { id: id }
      
  do next
