require "coffee-script"
fs = require "fs"
child = require "child_process"
seq = require "./seq"

# Configuration: source files
cssSource = "css"
indexSource = "templates/index.html"
coffeeSource = "client"
command = "coffee --print --compiler #{coffeeSource}/*.coffee"  

# Serving content at an URL
serve = (app, url, content, type = "text/html") ->
  console.log "Static content: ", url, type
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
        seq.iter read, files, ->
          serve app, "/app.css", content.join("\n"), "text/css"
          do next

    # Client coffeescript is compiled
    (next) ->
      child.exec command, (err,appJs) ->
        serve app, "/app.js", appJs, "application/javascript"
        do next

    # Index HTML is compiled as-is
    (next) -> 
      fs.readFile indexSource, "utf8", (err,indexHtml) ->
        serve app, '*', indexHtml, "text/html"
        do next

  ], next


