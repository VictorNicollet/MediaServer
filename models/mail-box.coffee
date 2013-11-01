require 'coffee-script'
Index = require '../index'
Mail  = require './mail'

# Queries for all the mail in a box, sorted by the date of
# the mail.

module.exports.All = do ->

  i = new Index "mail/in-box"

  Mail.runOnUpdate (store,mail,next) ->

    data = 
      from: mail.from()
      to: mail.to()
      subject: mail.subject()
      top: mail.top()
      toC: mail.toCount()

    att = mail.parts() > 0
    status = mail.status()
    date = mail.date()
    box = mail.box()

    keys = [
      [ box + '/from/' + mail.from(), date ]
      [ box + '/to/' + mail.to(), date ]
    ]

    if att
      data.att = true
      keys.push [ box + '/att/', date ]

    if status
      data.status = status
      keys.push [ box + '/status/' + status, date ]

    i.add store, mail.id(), data, keys, next

  (store, box) -> i.query(store,box)
