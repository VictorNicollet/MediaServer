require 'coffee-script'
store = require './store'
api = require './api'

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
makeAlbum = (albums,title) ->
  title: title
  get: []
  put: []
  id: nextId albums
  
module.exports.install = (app,next) ->

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->
    newAlbums = null
    update = (albums,next) ->
      newAlbums = albums || defaultAlbums
      title = req.body.title || "Untitled"
      album = makeAlbum newAlbums, title
      newAlbums.albums.push album
      next null, newAlbums
    store.updateJSON 'albums.json', update, (err) -> 
      return fail err if err
      json newAlbums 


  do next
