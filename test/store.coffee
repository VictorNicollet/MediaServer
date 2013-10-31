require 'coffee-script'
store = require('../store').testMode()

exports["test store#getObject on missing key"] = (beforeEnd,assert) ->
  store.get "missing", (err,data) ->
    assert.isNull err
    assert.isNull data

    
