coffeescript = require "coffee-script"
fs = require "fs"
child = require "child_process"
seq = require "./seq"

# Configuration: source files
cssSource = "css"
indexSource = "templates/index.html"
coffeeSource = "client"
command = "coffee --print --compile #{coffeeSource}/*.coffee"  

# Serving content at an URL
serve = (app, url, content, type = "text/html") ->
  console.log "Static content: #{url} (#{content.length} chars)"
  app.get url, (request, response) ->
    response.set "Content-Type", type
    response.send content

# Install the module
module.exports.install = (app, next) ->
  seq.run [

    # CSS files are concatenated together
    (next) ->
      content = []
      read = (file, next) ->
        file = cssSource + "/" + file
        fs.readFile file, "utf8", (err,css) ->
          console.log "Include CSS: ", file
          content.push css
          do next
      fs.readdir cssSource, (err,files) ->
        files = (file for file in files when /.css$/.test file)
        seq.iter read, files, ->
          serve app, "/app.css", content.join("\n"), "text/css"
          do next

    # Client coffeescript is compiled
    (next) ->
      content = []

      read = (file, next) ->
        file = coffeeSource + "/" + file
        fs.readFile file, "utf8", (err,coffee) ->
          console.log "Include Coffeescript: ", file
          content.push coffee
          do next

      compile = -> 
        appJs = coffeescript.compile content.join ''
        serve app, "/app.js", appJs, "application/javascript"
        do next

      files = require "./client/order.json"
      seq.iter read, files, ->
        do compile

    # Index HTML is compiled as-is
    (next) -> 
      fs.readFile indexSource, "utf8", (err,indexHtml) ->
        serve app, '*', indexHtml, "text/html"
        do next

  ], next


