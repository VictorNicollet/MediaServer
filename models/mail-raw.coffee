require 'coffee-script'
crypto = require 'crypto'
MailParser = require('mailparser').MailParser
Proof = require '../proof'
Model = require '../model'

Prefix =
  raw: "mail/raw"
  parts: (id) -> "mail/parts/#{id}"

# A part of a raw e-mail. Generated internally.
 
class Part

  constructor: (@_store, mailId, part) ->

    # The MIME-type of the part
    @type  = part.type

    # The file name of the part, if any
    @name  = part.name

    # The size of the part, in bytes
    @size  = part.size

    # If the contents of the part are provided, save them.
    @_cache = part.content || null
    
    @_path = "#{Prefix.parts mailId}/#{part.md5}"

   # Asynchronously load the part data.
   getData: (next) ->
     return next null, @_cache if @_cache != null 
     @_store.get @_path, next

   # Generate a public download URL for the part data.   
   url: ->
     @_store.getUrl @_path

# An individual e-mail, parsed from its raw form into a clean
# object format. Raw e-mails are immutable. 

class MailRaw

  # A raw e-mail is always read-only. 
  
  constructor: (proof,@_readonly,json,@_store) ->

    @_id = proof.id

    # If no JSON is provided, a weird bug must have happened.
    throw "Raw mail '#{@_id}' does not exist" if !json

    # If not readonly, issue an early warning
    throw "Raw mail is read-only" if !@_readonly

    @_access   = if Proof.check proof then true else false
    @_headers  = json.headers

    # The HTML body of the e-mail, null if missing.
    @html      = json.html

    # The text body of the e-mail, null if missing.
    @text      = json.text

    # The attached mail parts.
    @parts     = (new Part @_store, @_id part for part in json.parts)

    # The 'from', 'to', 'cc' and 'bcc' addresses
    @from      = json.from
    @to        = json.to
    @cc        = json.cc
    @bcc       = json.bcc

    # The subject of the e-mail
    @subject   = json.subject

  # The identifier of this raw e-mail

  id: -> @_id

  # Return a header by name, if possible
   
  header: (name) ->
    if name of @_headers then @_headers[name] else null
   
# ------------------
# Install the module      

Model.define module, MailRaw, (id) -> "#{Prefix.raw}/#{id}.json"

# Don't allow updates...
delete exports.update

# Save a raw mail to the store.
exports.save = (store,raw,next) ->

  # The identifier of an e-mail is the MD5 of its raw data,
  # so that reading the same e-mail multiple times does not
  # create multiple copies.
  
  id = do ->
    hash = crypto.createHash 'md5'
    hash.update raw
    hash.digest 'hex'

  prefix = Prefix.parts id
  path = "#{Prefix.raw}/#{id}.json"

  # Saving a part is a typical downloadable file upload.
  # Here, `part` contains the following:
  #  - `type`: the MIME-type
  #  - `name`: the file name, null if none
  #  - `content`: the binary content of the file
  # If successful, returns the part identifier (its md5)
  
  savePart = (part,next) -> 
    store.uploadFile prefix, part, next

  # This function is called after all the parts have been
  # saved (and their md5 computed)

  saveMail = (mail) ->

    getContent = (next) ->
      next null, JSON.stringify mail

    store.put path, getContent, (err) -> 

      return next err, null if err
      
      # This will cause every module that's listening to new mail
      # coming in to actually process the e-mail.

      setImmediate -> module.exports.touch store, [id]

      next null, id

  # This loop saves all the parts, then the mail itself.

  saveLoop = (mail,i) -> 
    return saveMail mail if i == mail.parts.length
    savePart mail.parts[i], (err,md5) ->
      return next err if err
      mail.parts[i].md5 = md5
      delete mail.parts[i].content if mail.parts[i].size > 1024
      saveLoop mail, i+1

  # Asynchronously parse the mail.

  mailparser = new MailParser()

  mailparser.on 'end', (parsed) ->

    mail =
      subject: parsed.subject
      html: parsed.html || null
      text: parsed.text || null
      from: parsed.from || []
      to: parsed.to || []
      cc: parsed.cc || []
      bcc: parsed.bcc || []
      headers: parsed.headers || {}
      parts: []

    for attachment in parsed.attachments || []
      part =
        type: attachment.type
        name: null
        size: attachment.length
        content: attachment.content
      if attachment.contentDisposition == 'attachment'
        part.name = attachment.fileName || null
      if part.type && part.size          
        mail.parts.push part    
            
    saveLoop mail, 0
  
  mailparser.write raw
  mailparser.end()

# Touch all the raw e-mail in a store

module.exports.touchAll = (store,next) ->
  touch = (id,next) ->
    id = id.substring 0, id.length - ".json".length
    module.exports.touch store, [{id:id}], ->
      next true
  store.withPrefix Prefix.raw, touch, next


