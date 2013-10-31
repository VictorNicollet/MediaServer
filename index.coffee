require 'coffee-script'
deepequal = require 'deep-equal'

# An index binds keys and data to identifiers.
#
# Each key is made from two string sub-keys:
#  - a set key, supports only equality tests
#  - a sort key, supports comparison
# 
# Typical queries are of the form:
# 
#     SELECT id, data FROM index WHERE setkey = A ORDER BY sortkey

class Index

  # An index uses a prefix for storing the various files it needs.
  
  constructor: (prefix) ->

    # The `pIndex`, or index prefix, is used to store individual
    # index files (one for each set key)
    @_pIndex = prefix + '/index/'

    # The `pSets`, or sets prefix, is used to store one file for
    # each bound identifier, containing all the sets in which that
    # identifier is be present (may include sets where it is NOT
    # present, if a crash happens while updating the set).
    @_pSets = prefix + '/sets/'

  # Prepares the sets-file for the specified identifier.
  #
  # This should be done BEFORE the identifier is added or removed
  # from the actual sets, to respect the invariant if a crash occurs.
  #
  # After an identifier is removed from an actual set, use
  # `_cleanSetFile`. 
  # 
  # This returns (asynchronously) any sets to which the identifier
  # may belong, and from which it will need to be removed.

  _prepareSetFile: (store, id, sets, next) ->    

    toRemove = []
            
    update = (json, next) ->
      json = json || { sets: [] }
      sets = sets.slice 0
      for set in json.sets
        if !(set in sets)
          sets.push set
          toRemove.push set
      next null, { sets: sets }
      
    store.updateJSON @_pSets + id, update, (err) ->
      return next err, null if err
      next null, toRemove

  # Adds an identifier, its corresponding data, and the provided
  # sort bindings to an index file identified by `set`. 
  
  _addToIndexFile: (store, id, set, sortkeys, data, next) ->

    update = (json,next) ->

      json = json || { ids: [], keys: [], data: [] }

      # Index files can get quite big, so let's try to track changes
      # and not write an index file to storage unless relevant
      # changes did happen.

      changed = false

      # For keeping things short, identifiers are stored separately
      # in `json.ids`, and referenced internally using integers
      # called "pos"

      created = false 
      posOfId = json.ids.indexOf id
      if posOfId == -1
        created = true
        posOfId = json.ids.length
        json.ids.push id

      # The data may have changed, so update it. Since the data is
      # a JSON-serializable object, use deep equality to determine
      # whether it did change/

      if json.data.length == posOfId 
        json.data.push data
      else
        changed = ! deepequal json.data[posOfId], data
        json.data[posOfId] = data

      # Run through the sort keys, looking for any that do
      # reference the object but are not part of the current
      # set of keys, and remove them. Remember which ones were
      # kept, so as not to add them a second time.

      foundkeys = []

      if !created

        l = 0
        bits = []
        for key, i in json.keys
          continue if key[1] != posOfId
          if key[0] in sortkeys
            foundkeys.push key[0]
            continue
          bits.push json.keys.slice l, i if l != i      
          l = i + 1
            
        if l != 0
          json.keys = [].merge.call([],bits)
          changed = true

      # Sort the keys remaining keys, then insert them in one pass.

      keys = (key for key in sortkeys when !(key in foundkeys))

      if keys.length > 0

        changed = true
        keys.sort()

        i = json.keys.length + keys.length - 1
        while keys.length > 0
          j = i - keys.length
          if j < 0 || json.keys[j][0] < keys[keys.length - 1]
            json.keys[i] = [keys.pop(), posOfId]
          else
            json.keys[i] = json.keys[j]

      next null, if changed then json else null

    store.updateJSON @_pIndex + set, update, next      

  # Removes an identifier from an index file. 

  _removeFromIndexFile: (store, id, set, next) ->

    update = (json,next) ->

      return next null, null if !json

      # Make sure that the identifier is part of the index file, and
      # early-out if it isn't.
  
      posOfId = json.ids.indexOf id
      if posOfId == -1
        return next null, null

      # Special case for when this is the last identifier in the index.

      if json.ids.length == 1
        return next null, { ids: [], data: [], keys: [] }

      # We already know that all keys related to the identifier will
      # have to be removed

      do ->
        
        l = 0
        bits = []
        for key, i in json.keys
          continue if key[1] != posOfId
          if key[0] in sortkeys
            foundkeys.push key[0]
            continue
          bits.push json.keys.slice l, i if l != i      
          l = i + 1
            
        if l != 0
          json.keys = [].merge.call [], bits             

      # Special case for where this is the identifier at the highest
      # position in the index.

      if json.ids.length == posOfId + 1
        json.ids.pop()
        json.data.pop()
        return next null, json

      # General case: swap with the last identifier.

      json.ids[posOfId] = json.ids.pop()
      json.data[posOfId] = json.data.pop()
      posOfNew = json.ids.length

      key[1] = posOfId for key in json.keys when key[1] == posOfNew
         
      return next null, json

    store.updateJSON @_pIndex + set, update, next      
        
  # Marks an identifier as removed from several index files in the set file
  # for that identifier. This should be done after the removal.

  _cleanSetFile: (store, id, rmsets, next) ->

    update = (json,next) ->
      return next null, null if !json 
      sets = (set for set in json.sets when !(set in rmsets))
      next null, (if sets.length == json.sets.length then null else { sets: sets })
      
    store.updateJSON @_pSets + id, update, next

  # Adds an identifier's bindings to the index. The list of keys is a list of
  # set/sort pairs.

  add: (store, id, data, keys, next) ->

    # Reshape the data so that we can work with individual sets
    # separately.
     
    sets = []
    sortkeysBySet = {}

    for keypair in keys
      if keypair[0] of sortkeysBySet
        sortkeysBySet[keypair[0]].push keypair[1]
      else
        sortkeysBySet[keypair[0]] = [keypair[1]]
        sets.push keypair[0]

    @_prepareSetFile store, id, sets, (err,unsets) =>
      return next err if err
      
      # This loop adds the id to all the sets.       
      addLoop = (i,next) =>
        if i == sets.length
          do next
        else
          @_addToIndexFile store, id, sets[i], sortkeysBySet[sets[i]], data, (err) ->
            return next err if err
            addLoop i+1, next
            
      addLoop 0, (err) =>
        return next err if err 

        # This loop removes the id from all the unsets
        rmLoop = (i,next) =>
          if i == unsets.length
            do next
          else
            @_removeFromIndexFile store, id, unsets[i], (err) ->
              return next err if err
              rmLoop i+1, next

        rmLoop 0, (err) =>
          return next err if err          
          @_cleanSetFile store, id, unsets, next

  # A query uses a fluent interface for building searches in the index. A query
  # reads from a single set, between two sort keys, in ascending or descending
  # order. It may skip values. By default, it returns only 10 elements, though the
  # limit may be made higher.
  #
  # Returned elements contain the id, the sort-key, and the data.  
  
  query: (store, set) ->
    
    before = null
    after  = null
    desc   = false
    limit  = 10
    offset = 0

    run = (next) =>

      store.getJSON @_pIndex + set, (err,data) ->
        return next err if err
        return next null, [], 0 if data == null || data.keys.length == 0

        k = data.keys

        # The starting point is either 0, or the first element equal to
        # "after" (found by binary search).

        s = 0        
        if after != null && k[0][0] < after
          
          a = 0
          b = k.length

          while b - a > 1
            m = Math.floor((a + b) / 2)
            if k[m][0] < after
              a = m
            else
              b = m

          s = b

        # The ending point is either the last element, or the last element
        # equal to "before" (found by binary search).
        #
        # We need the ending point to compute the count.
        
        e = k.length 
        if before != null && k[e-1][0] > before

          a = 0
          b = k.length

          while b - a > 1
            m = Math.floor((a + b) / 2)
            if k[m][0] > before
              b = m + 1
            else
              a = m + 1

          e = b

        # Simply extract values in the interval, taking offset and limit
        # into account.
         
        i = s + offset

        out = []
        while i < e && out.length < limit
          out.push [k[i][0], data.ids[k[i][1]], data.data[k[i][1]]]
          i++

        next null, out, e - s
      
    query =
      before: (b) ->
        before = b
        @
      after: (a) ->
        after = a
        @
      limit: (l) ->
        limit = l
        @
      offset: (o) ->
        offset = o
        @
      descending: (d) ->
        desc = d
        @
      run: run
    query
      
module.exports = Index
