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

# Register a reaction to a POST request
module.exports.post = register (app) -> (url, action) -> app.post url, action
