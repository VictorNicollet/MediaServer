require "coffee-script"

proof = require "./proof"
html = require "./html"
express = require "express"
app = do express

app.use express.logger()

app.get '/', (request, response) ->
  response.send html.index()

port = process.env.port || 5000
app.listen port, ->
  console.log("Listening on " + port)
