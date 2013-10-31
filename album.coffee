require 'coffee-script'
Store = require './store'
api = require './api'
proof = require './proof'
AlbumSet = require './models/album-set'
Album = require './models/album'

# By default, store everything on S3

store = new Store require "./s3"

# Touch all the albums at startup
setImmediate -> AlbumSet.touch store, ['']
                                                
module.exports.install = (app,next) ->

  # Return the list of all available albums
  api.get app, 'albums', (req, fail, json) ->
    AlbumSet.get store, '', (err,albumSet) ->
      return fail err if err
      json
        admin:  albumSet.isAdmin req.email
        albums: albumSet.allForClient req.email

  # Set the access level for albums
  api.post app, 'albums/share', (req, fail, json) ->
    
    update = (albumSet,next) ->

      if !albumSet.isAdmin req.email
        return next "Only admins can share albums", null
        
      for id, change of req.body
        albumSet.share id, change, []
        
      next null, albumSet

    AlbumSet.update store, '', update, (err,albumSet) ->
      return fail err if err
      json { success: true }

  # Creating a new album, returning the entire new album set
  api.post app, 'album/create', (req, fail, json) ->

    album = null

    update = (albumSet,next) ->
      
      if !albumSet.isAdmin req.email
        return next "Only admins can create albums", null

      if albumSet.count() >= albumSet.maxAlbums
        return next "Maximum number of albums reached", null
      
      album = albumSet.create(req.body.name || "Untitled")

      next null, albumSet

    AlbumSet.update store, '', update, (err,albumSet) ->
      return fail err if err
      json { album: albumSet.forClient album, req.email }

  # Return the list of all pictures in an album
  api.post app, 'album/pictures', (req, fail, json) ->

    id = req.body.album
    return fail "Missing album signature." if !id 

    Album.get id, (err,album) ->
      return fail err if err
      return fail "You are not allowed to view this album." if !album.isReadable()      
      
      json { pictures: album.allForClient() }
      
  # Uploading a thumbnail
  api.post app, 'album/thumbnail', (req, fail, json) ->

    id = req.body.album
    return fail "Missing album signature." if !id

    thumb = do ->
      try
        new Buffer req.body.thumb, 'base64'
      catch error
        null
         
    return fail "Missing or invalid thumbnail." if !thumb

    md5 = req.body.picture
    return fail "Missing picture." if !md5

    thePicture = null
    
    update = (album,next) ->

      if !album.isWritable()
        return next "You may not update thumbnails in this album.", null
        
      album.setThumbnail md5, thumb, (err,pic) ->
        thePicture = pic if !err
        next err, album

    Album.update store, id, update, (err,album) ->
      return fail err if err
      json { picture: thePicture }       

  # Uploading a file
  api.post app, 'album/upload', (req, fail, json) ->

    file = req.files.file
    return fail "No picture provided." if !file
      
    id = do ->
      try
        JSON.parse req.body.album
      catch error
        null
      
    if !id
      return fail "Missing or garbled album signature." 

    thePicture = null

    update = (album,next) ->

      if !album.isWritable()      
        return next "You may not upload pictures to this album.", null

      album.upload file, (err,picture) ->
        thePicture = picture if !err
        next err, album

    Album.update store, id, update, (err,album) ->
      return fail err if err
      json { picture: thePicture}
      
  do next
