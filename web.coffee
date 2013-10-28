require "coffee-script"
proof = require "./proof"
statics = require "./statics"
session = require "./session"
seq = require "./seq"
album = require "./album"
mail = require './mail'
express = require "express"

app = do express
app.use express.bodyParser()
app.use express.logger()
app.use express.cookieParser()
    
startApplication = (app, next) -> 
  port = process.env.PORT || 5000
  app.listen port, ->
    console.log("Listening on " + port)
    do next

# All module initialization functions
installers = [
  mail.install,
  album.install,
  session.install,
  statics.install,
  startApplication
]

# Loop through all installers and call them
call = (f, next) -> f app, next
seq.iter call, installers, -> 
