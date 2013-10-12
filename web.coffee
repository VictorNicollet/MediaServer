express = require "express"
app = do express

app.use express.logger()

app.get '/', (request, response) ->
  response.send 'Hello World!'

port = process.env.port || 5000
app.listen port, ->
  console.log("Listening on " + port)
