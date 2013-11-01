require 'coffee-script'
MailRaw = require './models/mail-raw'
Mail = require './models/mail'
MailBox = require './models/mail-box'
MailPop = require './mail-pop'
Thread = require './thread-limiter'

Store = require './store'
store = new Store require './s3'

module.exports.install = (app,next) ->

  # Run through existing data to rebuild indexes and
  # fix crash consequences
  Thread.start [
    (next) -> MailRaw.touchAll store, next
    (next) -> Mail.touchAll store, next
  ]

  # Install asynchronous polling
  MailPop.startPolling store

  do next
