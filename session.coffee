require "coffee-script"
proof = require "./proof"

# The name of the cookie that stores the session information
cookieName = "S"

# The session object only stores the e-mail of the user
# Session proof lasts one day
sessionOfEmail = (email) ->
  dict = { "email" : email }
  return proof.make dict, 60 * 24

# Install the session module
module.exports.install = (app,next) ->

  # React to login requests by setting the appropriate cookie
  app.post '/api/login', (request,response) -> 
    console.log request.body

  do next
