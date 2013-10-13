require "coffee-script"

proof = require "./proof"
express = require "express"
app = do express

app.use express.logger()

app.get '/', (request, response) ->
  data =
    "hello": "world"
  response.send JSON.stringify proof.make(data)

port = process.env.port || 5000
app.listen port, ->
  console.log("Listening on " + port)
