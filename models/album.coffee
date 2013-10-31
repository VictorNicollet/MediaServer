require 'coffee-script'
Proof = require '../proof'
Model = require '../model'

getThumbUrl = (store,id,md5) ->
  return null if md5 == null 
  store.getUrl "album/#{id}/thumb/#{md5}"
  
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

  constructor: (proof,@_readonly,json,@_store) ->

    # If no JSON is provided, this means the object does not exist
    # yet, so assume default values
    json = json || { pics: [], thumbs: [] }

    @_access  = if Proof.check proof then proof.access else null
    @_id      = proof.id

    @_pics    = json.pics
    @_thumbs  = json.thumbs
    @_changed = false

    # There should be one thumbnail for every picture, not less...
    @_thumbs.push null while @_thumbs.length < @_pics.length
    # ...and not more
    @_thumbs.length = @_pics.length

  # The identifier of this album.

  id: -> @_id

  # Create a parseable JSON object for this album.

  serialize: ->

    throw "This object is readonly" if @_readonly

    json =
      pics: @_pics
      thumbs: @_thumbs
    json
    
  # Can this album be changed by the current user ? 

  isWritable: -> @_access == 'PUT' && !@_readonly

  # Can this album be read by the current user ?

  isReadable: -> @_access != null

  # Has this album changed since it was loaded ?

  hasChanged: -> @_changed

  # How many pictures are there in this album ?

  pictureCount: -> @_pics.length

  # What is the selected album thumbnail ?
  # Picks the first available thumbnail.

  albumThumbnail: ->
    return thumb for thumb in @_thumbs when thumb != null
    return null

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
    url = @_store.getUrl "album/#{@_id}/original/#{@_pics[i]}" 
    thumb = url
    if @_thumbs[i] != null
      thumb = getThumbUrl @_store, @_id, @_thumbs[i]
    
    picture =
      id: pic
      url: url
      thumb: thumb
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

    @_store.uploadFile "album/#{@_id}/original", file, (err,md5) =>

      next err, null if err

      i = @indexOf md5
      if i == null
        i = @_pics.length
        @_pics.push md5
        @_thumbs.push null
        @_changed = true

      next null, @forClient i

  # Set the thumbnail for a picture
  #
  # The `thumb` should be a JPEG-encoded thumbnail. It will be bound
  # to the picture with original MD5 `md5`.

  setThumbnail: (md5,thumb,next) ->

    i = @indexOf md5
    return next "Unknown picture #{md5}.", null if i == null

    if @_thumbs[i] != null
      "nothing" # TODO: delete old thumbnail here

    file =
      type: 'image/jpeg'
      name: 'thumb.jpg'
      content: thumb

    @_store.uploadFile "album/#{@_id}/thumb", file, (err,md5) =>
      next err, null if err
      @_changed = true if @_thumbs[i] != md5
      @_thumbs[i] = md5
      next null, @forClient i 

# ------------------
# Install the module

Model.define module, Album, (id) -> "album-#{id}.json"

module.exports.getThumbUrl = getThumbUrl
