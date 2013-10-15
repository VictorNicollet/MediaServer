require "coffee-script"

# Register a reaction to an API query
register = (how) ->
  (app,url,f) ->
    url = '/api/' + url
    console.log "API registered: #{url}"
    reg = how app
    reg url, (req,res) ->
      json = (data,more=null) ->
        more res if more != null
        res.set "Content-Type", "application/json"
        res.send JSON.stringify data
      fail = (error) ->
        json {"error":error}
      f req, fail, json

# -------------------------------------------------------------------------------
# Without login

# Register a reaction to a POST request without login
module.exports.postGuest = register (app) -> (url, action) -> app.post url, action

# -------------------------------------------------------------------------------
# With login

# Function called when acting as a logged in user
sessionHandler = (req,res,action) -> action req, res
module.exports.setSessionHandler = (handler) -> sessionHandler = handler

# Wrapper around actions when logging in
withSession = (action) -> (req,res) -> sessionHandler req, res, action

# Register a reaction to a POST request
module.exports.post = register (app) -> (url, action) -> app.post url, withSession action

# Register a reaction to a GET request
module.exports.get = register (app) -> (url, action) -> app.get url, withSession action
