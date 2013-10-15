require 'coffee-script'
store = require './store'
api = require './api'
proof = require './proof'

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

# Grab all visible albums for a given user
grabVisibleAlbums = (albums,email) -> 
  grab = (album) ->
    name: album.name
    id: nextId albums
    access:
      if isAdmin then 'OWN' else
        if album.put.indexOf emailId != -1 then 'PUT' else
          if album.get.indexOf emailid != -1 then 'GET' else ''
  isAdmin = albums.admins.indexOf email != -1
  emailId = albums.contacts.indexOf email
  grabbed = (grab album for album in albums.albums)
  (proof.make album for album in grabbed when album.access)
  
module.exports.install = (app,next) ->

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->
    newAlbums = null
    update = (albums,next) ->
      newAlbums = albums || defaultAlbums
      name = req.body.name || "Untitled"
      album = makeAlbum newAlbums, name
      newAlbums.albums.push album
      next null, newAlbums
    store.updateJSON 'albums.json', update, (err) -> 
      return fail err if err
      json { albums: grabVisibleAlbums newAlbums }


  do next
