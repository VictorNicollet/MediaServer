require "coffee-script"
fs = require "fs"
child = require "child_process"

# Configuration: source files
indexSource = "templates/index.html"
coffeeSource = "client/*.coffee"
command = "coffee --print --compiler #{coffeeSource}"  

# Install the module
module.exports.install = (app, next) ->
  fs.readFile indexSource, "utf8", (err,indexHtml) ->
    child.exec command, (err,appJs) ->

      app.get "/app.js", (request, response) ->
        response.send appJs

      app.get '*', (request, response) ->
        response.send indexHtml

      do next
