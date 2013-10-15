require "coffee-script"
verify = do require "browserid-verify"
proof = require "./proof"
api = require "./api"

# The audience used for Persona login
audience = process.env.audience || 'http://docs.nicollet.local:5000'

# The name of the cookie that stores the session information
cookieName = "S"

# The session object only stores the e-mail of the user
# Session proof lasts one day
sessionOfEmail = (email) ->
  dict = { "email" : email }
  return proof.make dict, 60 * 24

setCookie = (email) -> (res) ->
  session = sessionOfEmail email
  policy = { maxAge: 24 * 3600 * 1000 }
  res.cookie cookieName, JSON.stringify(session), policy 

# Enrich the API module with a session handler
api.setSessionHandler (req, res, action) ->

  noSession = ->
    res.set "Content-Type", "application/json"
    res.cookie cookieName, "", { maxAge: 0 }
    res.send JSON.stringify { error: "Not logged in", requiresLogin: true }

  try
    cookie = req.cookies[cookieName]
    cookie = JSON.parse cookie
    return noSession() if !proof.check cookie
    req.email = cookie.email
    setCookie(cookie.email)(res)
    action req, res
  catch error
    console.log error
    return noSession()


# Install the session module
module.exports.install = (app,next) ->

  # React to login requests by setting the appropriate cookie
  api.postGuest app, 'login', (req,fail,json) -> 

    assertion = req.body.assertion || ''
    if assertion == ''
      return fail "Internal login error: no Persona assertion provided"

    verify assertion, audience, (err,email) ->
  
      return fail("Persona verification failed: " + err) if err
      return fail "Persona assertion was invalid" if !email

      # Set the cookie as part of the "more" option on json responses
      json {"success":true}, setCookie(email)

  do next
