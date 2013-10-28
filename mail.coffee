require 'coffee-script'
POP3Client = require 'poplib'

poll = ->
  
  client = new POP3Client 110, 'nicollet.net',
    tlserrs: false,
    enabletls: false,
    debug: true
    
  client.on 'connect', ->
    console.log "CONNECTED!"
    client.login "victor-pop", "pop3"
    
  client.on 'login', (status,raw) ->
    console.log 'On LOGIN:', raw
    do client.list if status

  client.on 'list', (status, count, nbr, messages) -> 
    console.log "Messages:", messages
    for msg, i in messages when msg
      client.retr i

  client.on 'retr', (status, nbr, data) ->
    console.log "Data for", nbr, "is:", data

module.exports.install = (app,next) ->
  do next
  setTimeout poll, 1000
