trigger = require "../trigger"

exports["test trigger#onReceive > trigger#send"] = (beforeExit,assert) ->
  t = trigger.make()
  called = false

  t.onReceive (v) -> called = v
  t.send true

  assert.ok called

exports["test trigger#send > trigger#onReceive"] = (beforeExit,assert) ->
  t = trigger.make()
  called = false

  t.send true
  t.onReceive (v) -> called = v

  assert.ok called
