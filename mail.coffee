require 'coffee-script'
POP3Client = require 'poplib'
MailRaw = require './models/mail-raw'

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
  
  client = new POP3Client config.port, config.host,
    tlserrs: false,
    enabletls: false,
    debug: false
    
  client.on 'connect', ->
    client.login config.user, config.pass
    
  client.on 'login', (status,raw) ->
    do client.list if status

  toBeRetrieved = []
  retrieveNext = ->
    if toBeRetrieved.length == 0
      client.quit() 
    else
      client.retr toBeRetrieved.shift()
    
  client.on 'list', (status, count, nbr, messages) -> 
    for msg, i in messages when msg
      toBeRetrieved.push i
      break if toBeRetrieved.length > config.batch
    do retrieveNext  

  client.on 'retr', (status, nbr, data) ->
    MailRaw.save store, data, (err) ->
      if err
        do retrieveNext
      else
    client.dele nbr

  client.on 'dele', () ->
    do retrieveNext

  client.on 'quit', () ->
    do next 
        
poll = ->  
  grabMail defaultConfig, ->
    console.log "POP3 polling done !"

module.exports.install = (app,next) ->
  do next
  setTimeout poll, 1000
