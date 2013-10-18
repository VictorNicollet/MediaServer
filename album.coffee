require 'coffee-script'
Store = require './store'
api = require './api'
proof = require './proof'
AlbumSet = require './models/album-set'

# You cannot have more than this number of pictures in an album
maxPictures = 250

# The default piclist
defaultPiclist = ->
  pics: []
  thumbs: []

# Get a signed picture
getSignedPicture = (album,piclist,i) ->

  url = Store.getUrl S3Key.original album, piclist.pics[i]
  thumb = url
  if piclist.thumbs[i] != null
    thumb = Store.getUrl S3Key.thumb album, piclist.thumbs[i]

  obj =
    picture: piclist.pics[i]
    url: url
    thumb: thumb

  proof.make obj 


# The S3 keys
S3Key =
  album: (album) -> "album-#{album.id}.json"
  originalPrefix: (album) -> "album/#{album.id}/original"
  original: (album,md5) -> "album/#{album.id}/original/#{md5}"
  thumbPrefix: (album) -> "album/#{album.id}/thumb"
  thumb: (album,md5) -> "album/#{album.id}/thumb/#{md5}"
        
module.exports.install = (app,next) ->

  # Return the list of all available albums
  api.get app, 'albums', (req, fail, json) ->
    AlbumSet.get (err,albumSet) ->
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

    AlbumSet.update update, (err,albumSet) ->
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

    AlbumSet.update update, (err,albumSet) ->
      return fail err if err
      json { album: albumSet.forClient album }

  # Return the list of all pictures in an album
  api.post app, 'album/pictures', (req, fail, json) ->

    album = req.body.album
    if !album || !proof.check album
      return fail "Invalid album signature."

    Store.getJSON S3Key.album(album), (err,data) ->
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

    Store.uploadFile S3Key.thumbPrefix(album), file, (err,id2) -> 
      return fail err if err

      update = (piclist,next) ->
        piclist = piclist || defaultPiclist()
        pos = piclist.pics.indexOf id
        return next "Picture not found in album.", null if pos == -1
        return next null, null if piclist.thumbs[pos] == id2
        piclist.thumbs[pos] = id2
        newPicture = getSignedPicture album, piclist, pos
        next null, piclist

      Store.updateJSON S3Key.album(album), update, (err) ->
        return fail("When updating album: #{err}") if err
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
      
    if !album || !proof.check album || album.access != "PUT" 
      return fail "Invalid album signature." 

    Store.uploadFile S3Key.originalPrefix(album), file, (err,id) ->

      return fail("When uploading file: #{err}") if err

      thePicture = null

      update = (piclist,next) ->
        piclist = piclist || defaultPiclist()
        pos = piclist.pics.indexOf id
        return next null, null if pos != -1
        piclist.thumbs.push null
        piclist.pics.push id
        thePicture = getSignedPicture album, piclist, piclist.pics.length - 1
        next null, piclist
        
      Store.updateJSON S3Key.album(album), update, (err) ->
        return fail("When updating album: #{err}") if err
        json { picture: thePicture }
      
  do next
