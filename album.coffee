require 'coffee-script'
store = require './store'
api = require './api'
proof = require './proof'

# You cannot have more than this number of albums
maxAlbums = 20

# The global list of albums
defaultAlbums = 
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

isAdmin = (albums,email) ->
  album.admins.indexOf email != -1

# Grab all visible albums for a given user
grabVisibleAlbums = (albums,email) -> 
  grab = (album) ->
    name: album.name
    album: nextId albums
    access:
      if admin then 'OWN' else
        if album.put.indexOf emailId != -1 then 'PUT' else
          if album.get.indexOf emailId != -1 then 'GET' else ''
  admin = isAdmin albums, email
  emailId = albums.contacts.indexOf email
  grabbed = (grab album for album in albums.albums)
  (proof.make album for album in grabbed when album.access)
  
module.exports.install = (app,next) ->

  # Return the list of all available albums
  api.get app, 'albums', (req, fail, json) ->
    albums = store.getJSON 'albums.json', (err,albums) ->
      return fail err if err
      json { albums: grabVisibleAlbums albums, req.email }

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->
    album = null
    update = (albums,next) ->
      albums = albums || defaultAlbums
      if !isAdmin albums, req.email
        return next "Only admins can create albums", null
      if albums.length == maxAlbums
        return next "Maximum number of albums reached", null
      name = req.body.name || "Untitled"
      album = makeAlbum albums, name
      albums.albums.push album
      next null, albums
    store.updateJSON 'albums.json', update, (err) -> 
      return fail err if err
      json { album: album }

  do next
