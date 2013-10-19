require 'coffee-script'
Store = require '../store'
Proof = require '../proof'

# An album is a set of pictures. It contains all necessary
# information for rendering those pictures, including
# rotation, thumbnails, and "hidden" status.
#
# Album-related information, such as the name or the
# sharing rules, are held by the `AlbumSet`.

class Album

  # The maximum number of pictures that can be found in
  # an album

  maxPictures: 250

  # An album may be loaded read-only, or be loaded in read-write
  # fashion as part of an update transaction. All update operations
  # are supported while in readonly mode, *but* serialization will not
  # be supported.
  #
  # The optional JSON provided to the constructor has the same format
  # as that returned by `serialize`.
  #
  # The constructor receives a proof that grants the user access to
  # the album. Use `isReadable` and `isWritable` to test for
  # access righs.

  constructor: (proof,@_readonly,json = null) ->

    # If no JSON is provided, this measn the object does not exist
    # yet, so assume default values
    json = json ||
      pics: []
      thumbs: []

    @_access  = if Proof.check proof then proof.access else null
    @_id      = proof.id

    @_pics    = json.pics
    @_thumbs  = json.thumbs
    @_changed = false

    # There should be one thumbnail for every picture, not less...
    @_thumbs.push null while @_thumbs.length < @_pics.length
    # ...and not more
    @_thumbs.length = @_pics.length

  # Can this album be changed by the current user ? 

  isWritable: -> @_access == 'PUT' && !@_readonly

  # Can this album be read by the current user ?

  isReadable: -> @_access != null

  # Has this album changed since it was loaded ?

  hasChanged: -> @_changed

  # Get the index of a picture within the album, based on the md5
  # of its original. Returns null if not found.

  indexOf: (md5) ->
    i = @_pics.indexOf md5
    if i == -1 then null else i 

  # Get a signed picture for the client. The index may be either
  # an integer, or the original md5 of a picture.
  # 
  # If no thumbnail exists yet, the original image is used as
  # the thumbnail, relying on the client to generate and upload
  # the thumbnail on its own.

  forClient: (i) ->
    
    i = @indexOf(i) if typeof i == 'string'
    return null if i == null || i < 0 || i >= @_pics.length

    pic = @_pics[i]
    thumb = @_thumbs[i] || pic
    
    picture =
      id: pic
      url: Store.getUrl "album/#{@_id}/original/#{pic}"
      thumb: Store.getUrl "album/#{@_id}/original/#{thumb}"
    picture

  # Get all signed pictures.

  allForClient: () ->
    @forClient i for pic, i in @_pics
      
  # Upload a new picture to the album.
  #
  # Expected fields:
  #  `file.name` : the client-side name of the file
  #  `file.path` : where the file is stored on the server
  #  `file.type` : the MIME-type of the file
  #
  # Accepted mime-types are: `image/png`, `image/jpeg`
  #
  # Asynchronously returns the signed picture if the upload was
  # successful.
   
  upload: (file,next) ->
    
    if file.type != 'image/png' && file.type != 'image/jpeg'
      return next "Unsupported file type: #{file.type}.", null

    if @_pics.length >= @maxPictures
      return next "Maximum album size reached.", null

    Store.uploadFile "album/#{@_id}/original", file, (err,md5) ->

      next err, null if err

      i = @indexOf md5
      if i == null
        i = @_pics.length
        @_pics.push md5
        @_thumbs.push null

      next null, @forClient i

  # Set the thumbnail for a picture
  #
  # The `thumb` should be a JPEG-encoded thumbnail. It will be bound
  # to the picture with original MD5 `md5`.

  setThumbnail: (md5,thumb,next) ->

    i = @indexOf md5
    return next "Unknown picture #{md5}.", null if i == null

    if @_thumb[i] != null
      "nothing" # TODO: delete old thumbnail here

    file =
      type: 'image/jpeg'
      name: 'thumb.jpg'
      content: thumb

    Store.uploadFile "album/#{@_id}/thumb", file, (err,md5) ->
      next err, null if err
      @_thumb[i] = md5
      next null, @forClient i 

# The file URL of an album

url = (id) -> "album-#{id}.json"
    
# Grab a readonly copy of the album.
  
module.exports.get = (proof,next) ->
  Store.getJSON url(proof.id), (err,json) ->
    next err, null if err
    next null, new Album(proof,true,json)

# Grab a read-write copy of the album set, apply the
# `update` function to it, write it back to the persistent
# store, then call the `next` function on the updated set.
#
# If the `update` function does not change the album set,
# then nothing is written back to the persistent store
# (to save time).

module.exports.update = (proof,update,next) ->

  theAlbum = null

  realUpdate = (json,next) ->
    update new AlbumSet(proof,false,json), (err,album) ->
      theAlbum = album
      
      json = null
      if album != null && album.hasChanged()
        json = album.serialize()
         
      next null, json 

  realNext = (err) ->
    next err, null if err
    next null, theAlbum
  
  Store.updateJSON url(proof.id), realUpdate, realNext

