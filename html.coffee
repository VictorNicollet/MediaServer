require "coffee-script"
fs = require "fs"

indexSource = "templates/index.html"
indexHtml = ""

fs.readFile indexSource, "utf8", (err,data) ->
  indexHtml = data

# The HTML of the index page
module.exports.index = () -> indexHtml
