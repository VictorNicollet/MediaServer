require "coffee-script"
proof = require "./proof"
statics = require "./statics"
express = require "express"

app = do express

startApplication = (app, next) -> 
  app.use express.logger()
  port = process.env.port || 5000
  app.listen port, ->
    console.log("Listening on " + port)
    do next

# All module initialization functions
installers = [
  statics.install,
  startApplication
]

# Loop through all installers and call them
run = () ->
  return if installers.length == 0
  first = do installers.shift
  first app, run

  
