require 'coffee-script'
POP3Client = require 'poplib'
MailRaw = require './models/mail-raw'
Mail = require './models/mail'
MailBox = require './models/mail-box'
Thread = require './thread-limiter'

Store = require './store'
store = new Store require './s3'

defaultConfig =
  port: 110
  host: 'nicollet.net'
  user: 'victor-pop'
  pass: 'pop3'
  batch: 30

# Reads `config.batch` e-mails from the remote host, stores them 
# locally and (if local storage succeeded) deletes them from the
# remote host.
 
grabMail = (config, next) ->

  toBeRetrieved = []
  retrieveNext = ->
    if toBeRetrieved.length == 0
      client.quit() 
    else
      client.retr toBeRetrieved.shift()
      
  client = new POP3Client config.port, config.host,
    tlserrs: false,
    enabletls: false,
    debug: false
    
  client.on 'connect', ->
    client.login config.user, config.pass
    
  client.on 'login', (status,raw) ->
    return do next if !status
    do client.list
    
  client.on 'list', (status, count, nbr, messages) ->
    return do next if !status
    for msg, i in messages when msg
      toBeRetrieved.push i
      break if toBeRetrieved.length > config.batch
    do retrieveNext  

  client.on 'retr', (status, nbr, data) ->
    return do next if !status
    MailRaw.save store, data, (err) ->
      if err
        do retrieveNext
      else
    client.dele nbr

  client.on 'dele', (status) ->
    return do next if !status
    do retrieveNext

  client.on 'quit', () ->
    do next 
        
poll = () ->
  Thread.start ((next) -> grabMail defaultConfig, next), ->
    console.log "POP3 polling done !"
    setTimeout poll, 60000
  
module.exports.install = (app,next) ->
  Thread.start [
    (next) -> MailRaw.touchAll store, next
    (next) -> Mail.touchAll store, next
  ]
  do poll
  do next
