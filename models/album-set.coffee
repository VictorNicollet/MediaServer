require 'coffee-script'
Store = require '../store'
Proof = require '../proof'

# An album set contains the list of all albums available for an instance,
# along with access and sharing rules.

class AlbumSet

  # The maximum number of albums that can be found in an album set. The
  # main reason for this limitation is bandwidth issues.
   
  maxAlbums: 200

  # An album set may be loaded read-only, or be loaded in read-write
  # fashion as part of an update transaction. All update operations
  # are supported while in readonly mode, *but* serialization will not
  # be supported.
  #
  # The optional JSON provided to the constructor has the same format
  # as that returned by `serialize`.

  constructor: (@_readonly,json = null) ->

    # If no JSON is provided, this means the object does not exist
    # yet, so assume default values
    json = json ||
      admins: [ "victor@nicollet.net", "alix.marcorelles@gmail.com" ]
      contacts: []
      albums: []

    # In-memory, store the actual e-mails instead of stowing them
    # away in a contacts array
    extractContacts = (album) ->
      get:  (json.contacts[i] for i in album.get || [])
      put:  (json.contacts[i] for i in album.set || [])
      id:   album.id
      name: album.name 

    @_changed = false
    @_admins = json.admins || []
    @_albums = (extractContacts album for album in json.albums || [])

  # Has this album changed since it was loaded ?
  # 
  # Used by the update engine to avoid re-writing an albumset to
  # persistent storage if it has not changed at all.

  hasChanged: -> @_changed

  # Returns an album with the specified identifier.
  # Mostly used internally. If you retrieve an album, do not
  # alter its value unless you set the `_changed` flag.
  
  get: (id) ->
    for album in @_albums
      return album if album.id == id
    null

  # Share an individual album. This consists in changing the
  # album's `get` and `put` lists.

  share: (id,get,put) ->

    # Use a canonical form for arrays to correctly detect
    # changes.
    do get.sort
    do put.sort

    album = @get id
    return if album == null

    @_changed = @_changed ||
      get.join(';') != album.get.join(';') ||
      put.join(';') != album.put.join(';')

    album.get = get
    album.put = put

  # The identifier of the next album to be created.

  nextId: ->
    i = 0
    for album in @_albums
      i = album.id + 1 if album.id >= i
    i

  # The number of albums in this set

  count: -> @_albums.length

  # Returns true if the specified email is that of an album set
  # owner.

  isAdmin: (email) -> @_admins.indexOf(email) != -1    

  # Create a new album with the specified name, and returns it.

  create: (name) ->

    @_changed = true
    
    album =
      name:name
      put: []
      get: []
      id: @nextId()
    @_albums.push album
    album

  # Generate a client-friendly representation of an album. Contains
  # a proof with the album id and the access level (`GET` or `PUT`),
  # as well as the name.
  #
  # If the owner is an administrator, also returns the get and put
  # emails.
  # 
  # Argument can be an album object, or an album identifier. 

  forClient: (album, email) ->

    album = if typeof album == 'object' then album else @get album
    return null if album == null

    isAdmin = @isAdmin email
    
    access = if isAdmin || album.put.indexOf(email) != -1 then "PUT" else
      if album.get.indexOf(email) != -1 then "GET" else null
    return null if access == null
    
    value =
      id: Proof.make { id: album.id, access: access }
      name: album.name

    if isAdmin
      value.get = album.get
      value.put = album.put

    value

  # Returns client-friendly representations for all albums that the
  # client can see.

  allForClient: (email) ->
    albums = (@forClient album, email for album in @_albums)
    album for album in albums when album != null
                                            
  # Turn the album set into a JSON representation that can be saved to
  # disk. The returned representation can be passed back to the
  # constructor.

  serialize: ->
    throw "AlbumSet is readonly" if @_readonly

    # For better compression, all contact e-mails are stored in a
    # contact array. This involves some boilerplate code...
    contacts  = []
    contactId = (contact) ->
      i = contacts.indexOf(contact)
      return i if i != -1 
      contacts.push contact
      contacts.length - 1
    compressContacts = (emails) =>
      contactId email for email in emails when ! @isAdmin email

    compressAlbum = (album) ->
      name: album.name
      id:   album.id
      get:  compressContacts album.get
      put:  compressContacts album.put  
      
    json =
      admins: @_admins
      albums: compressAlbum album for album in @_albums
      contacts: contacts
    json

# Grab a readonly copy of the album set.
  
module.exports.get = (next) ->
  Store.getJSON "albums.json", (err,json) ->
    next err, null if err
    next null, new AlbumSet(true,json)

# Grab a read-write copy of the album set, apply the
# `update` function to it, write it back to the persistent
# store, then call the `next` function on the updated set.
#
# If the `update` function does not change the album set,
# then nothing is written back to the persistent store
# (to save time).

module.exports.update = (update,next) ->

  theAlbumSet = null

  realUpdate = (json,next) ->
    update new AlbumSet(false,json), (err,albumSet) ->
      theAlbumSet = albumSet
      
      json = null
      if albumSet != null && albumSet.hasChanged()
        json = albumSet.serialize()
         
      next null, json 

  realNext = (err) ->
    next err, null if err
    next null, theAlbumSet
  
  Store.updateJSON "albums.json", realUpdate, realNext
