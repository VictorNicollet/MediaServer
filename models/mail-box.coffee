require 'coffee-script'
Index = require '../index'
Mail  = require './mail'

# Queries for all the mail in a box, sorted by the date of
# the mail.

module.exports.All = do ->

  i = new Index "mail/in-box"

  Mail.runOnUpdate (store,mail,next) ->

    data = 
      att: mail.parts() > 0
      from: mail.from()
      to: mail.to()
      subject: mail.subject()
      top: mail.top()
      toC: mail.toCount()

    keys = [[ mail.box(), mail.date() ]]

    i.add store, mail.id(), data, keys, next

  (store, box) -> i.query(store,box)
