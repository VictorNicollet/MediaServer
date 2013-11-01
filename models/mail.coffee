require 'coffee-script'
Model = require '../model'
Proof = require '../proof'
MailRaw = require './mail-raw'
Thread = require '../thread-limiter'

Prefix =
  meta: "mail/meta"

# Used to implement getter/setter pairs.

getOrSet = (key) -> () ->
  return @[key] if arguments.length == 0
  value = arguments[0]
  @_changeIf(@[key] != value)
  @[key] = value
  @

# Meta-information and short summary about a mail.

class Mail 

  constructor: (proof,@_readonly,json,@_store) ->

    @_exists = json != null

    if @_exists
      @_subject = json.subject
      @_to      = json.to
      @_toC     = json.toC
      @_top     = json.top
      @_from    = json.from
      @_parts   = json.parts
      @_date    = json.date
      @_box     = json.box
    else
      @_box     = 0
      
    @_id = proof.id
    @_access = if Proof.check proof then proof.access else null

    @_changed = false

  # If argument is true, mark object as changed.
  # Throw an exception if this e-mail is readonly.
  _changeIf: (c=true) ->
    return if !c
    throw "Mail #{@_id} is read-only" if @_readonly
    @_changed = true

  # The identifier of this e-mail

  id: -> @_id
 
  # Does this e-mail really exist ?

  exists: -> @_exists

  # What is the subject of this e-mail ?
  # Call as a setter to update the subject.

  subject: getOrSet '_subject'

  # What is the to-address of this e-mail ?
  # Call as a setter to update the to-address.

  to: getOrSet '_to'

  # How many to-addresses (including cc and bcc) does this
  # e-mail have ? 

  toCount: getOrSet '_toC'

  # What are the first few words of this e-mail ?
  # Call as a setter to update the summary.

  top: getOrSet '_top'
 
  # What is the from-address of this e-mail ?
  # Call as a setter to update the from-address.

  from: getOrSet '_from'

  # How many parts does this e-mail have ?
  # Call as a setter to update the number of parts.

  parts: getOrSet '_parts'

  # What is the date on this e-mail ?
  # Call as a setter to update the e-mail date.

  date: getOrSet '_date'

  # What box is this e-mail stored in ?

  box: -> @_box

  # Has this mail changed since it was loaded ?

  hasChanged: -> @_changed
            
  # Serialize the mail information back to JSON

  serialize: ->

    throw "Mail #{@_id} is read-only" if @_readonly

    json =
      to: @_to || null
      toC: @_toC || 0
      subject: @_subject || ""
      top: @_top || ""
      from: @_from || null
      parts: @_parts || 0
      date: @_date 
      box: @_box
    json 
    
# ------------------
# Install the module

Model.define module, Mail, (id) -> "#{Prefix.meta}/#{id}.json"

MailRaw.runOnUpdate (store,raw,next) ->
  
  update = (mail,next) ->
            
    mail
      .subject(raw.subject)
      .to(if raw.to.length > 0 then raw.to[0].address else null)
      .from(if raw.from.length > 0 then raw.from[0].address else null)
      .toCount(raw.to.length)
      .parts(raw.parts.length)

    if raw.text
      text = raw.text.trim().replace(/\s+/g,' ')
      mail.top(if text.length > 200 then text.substring(0,200) else text)

    date = do ->
      input = raw.header "date"
      re = /^[^,]+, (\d+) ([^ ]+) (\d+) (\d+):(\d+):(\d+) ([+-])(\d\d)(\d\d)/
      matches = re.exec input
      try 
        day = parseInt matches[1], 10
        month = switch matches[2]
          when "Jan" then 1
          when "Feb" then 2
          when "Mar" then 3
          when "Apr" then 4
          when "May" then 5
          when "Jun" then 6
          when "Jul" then 7
          when "Aug" then 8
          when "Sep" then 9
          when "Oct" then 10
          when "Nov" then 11
          when "Dec" then 12
          else throw "Month!"
        year = parseInt matches[3], 10
        hour = parseInt matches[4], 10
        mins = parseInt matches[5], 10
        secs = parseInt matches[6], 10
        offt = if matches[7] == '+' then 1 else -1
        offh = parseInt matches[8], 10
        offm = parseInt matches[9], 10

        offset = offt * (offh * 60 + offm) * 60000

        new Date year, month, day, hour, mins, secs, offset
        
      catch err
        console.log "Could not parse date: #{input}"
        null

    mail.date(if date then date.toISOString() else null)

    next null, mail

  module.exports.update store, raw.id(), update, next
     
# Touch all the e-mail info in a store

module.exports.touchAll = (store,next) ->
  batch = Thread.batch()
  touch = (id,next) ->
    id = id.substring 0, id.length - ".json".length
    batch.start (next) -> module.exports.touch store, [{id:id}], next
    next true
  store.withPrefix Prefix.meta, touch, next

