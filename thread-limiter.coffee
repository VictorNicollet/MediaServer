require 'coffee-script'

# When a bunch of threads needs to start in parallel, limits the
# number that start running at any given time.

# The pending threads: when a thread finishes, a new thread is picked
# from this array and started.

pending = []

# The number of running threads.

runningCount = 0

# A constant: the ideal maximum number of threads.

maxCount = 20

# Start a pending thread, increase the number of running threads by one.
# Return asynchronously when the pending thread has finished. If no
# threads are pending, never returns. 

startPending = ->

  return false if pending.length == 0

  thread = pending.shift()
  runningCount++

  setImmediate ->
    thread ->
      do release

# Called when a thread finishes.

release = -> 
  runningCount--
  do startPending if runningCount < maxCount

# Start a batch of threads that are not expected to return a value,
# wait until all of them finish before returning asynchronously.

startBatch = (threads,next) ->

  return setImmediate next if threads.length == 0

  # RULE 1: always start at least one thread
  # RULE 2: never start more than half the remaining free
  #         thread, unless to respect rule 1.
  willStart = Math.floor((maxCount - runningCount) / 2)
  willStart = 1 if willStart < 1
  willStart = Math.min(threads.length,willStart)

  # Threads are wrapped to run 'next' when all of them have
  # finished running.
  expected = threads.length
  finished = 0

  wrap = (thread) ->
    ->
      thread ->
        if ++finished == expected
          setImmediate next
        do release
        
  wrappers = (wrap thread for thread in threads)

  # Start 'willStart' threads now, postpone the rest.
  # Since this might cause more threads to run, increment
  # running count first.
  runningCount += willStart
  while wrappers.length > 0 && willStart > 0
    do wrappers.shift()
    --willStart

  for wrapper in wrappers
    pending.push wrapper

# Start a single thread. This is done in order to know how many
# threads are currently running (and limit resource usage), but will
# not delay the thread.

startSingle = (thread,next) ->
  ++runningCount
  thread ->
    --runningCount
    next.call @, arguments

# Start a single thread, or a batch of threads. Calls 'next' when
# it is done. For single threads, 'next' will receive any callback
# data provided by the thread.
    
module.exports.start = (threadOrThreads, next = null) ->

  next = (->) if next == null

  if Array.isArray threadOrThreads
    startBatch threadOrThreads, next
  else
    startSingle threadOrThreads, next

# Create a batch. New threads can be added to the batch one after
# another. The batch will receive an allocation of thread slots
# when it starts up.

module.exports.batch = () ->

  # Allocate 1/3 of the free threads to a batch.
   
  free = Math.floor((maxCount - runningCount) / 3)
  free = 1 if free < 1

  used = 0

  obj =

    # Starting a new thread uses a free slot if available, uses the
    # general pending queue otherwise.
     
    start: (thread) ->
      wrapper = (next) ->
        ++used
        thread ->
          --used
          do next 
      
      if used < free
        runningCount++
        wrapper ->
          do release
      else
        pending.push wrapper
        
  obj
