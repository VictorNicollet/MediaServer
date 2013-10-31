require 'coffee-script'
POP3Client = require 'poplib'

defaultConfig =
  port: 110
  host: 'nicollet.net'
  user: 'victor-pop'
  pass: 'pop3'

pollNew = (config, each, next) ->
  
  client = new POP3Client config.port, config.host,
    tlserrs: false,
    enabletls: false,
    debug: true
    
  client.on 'connect', ->
    client.login config.user, config.pass
    
  client.on 'login', (status,raw) ->
    do client.list if status

  toBeRetrieved = []
  retrieveNext = ->
    return next() if toBeRetrieved.length == 0 
    client.retr toBeRetrieved.shift()
    
  client.on 'list', (status, count, nbr, messages) -> 
    for msg, i in messages when msg
      toBeRetrieved.push i
    do retrieveNext  

  client.on 'retr', (status, nbr, data) ->
    each data
    do retrieveNext

poll = ->
  
  pollNew defaultConfig, each, ->

module.exports.install = (app,next) ->
  do next
#  setTimeout poll, 1000
