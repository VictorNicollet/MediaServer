# Displaying album pages.

do ->

  # True if the user has administration rights on the albums.

  isAdmin = false

  # The list-of-all-albums model.

  A = new List (l,next) ->
    lock (unlock) ->
      get "albums", {}, (r) ->
        isAdmin = r.admin
        next r.albums
        unlock() 

  "/".route (r) ->

    r.table({class:"table album"})

      .thead().tr().td({colspan:3}).h2().esc("Albums")
      .close(4)

      .tbody {}, (r) ->

        A.all '', (l) ->

          for album in l 

            share = ''
            if isAdmin
              c = album.get.length + album.put.length
              if c > 0              
                share = if c == 1
                then "Shared with 1 person"
                else "Shared with #{count} people"

            r.tr()
              .td({class: 'rowsize'}).span().esc(album.size || '').close(2)
              .td().a({ href: "/album/" + album.id.id }).esc(album.name)

            if album.thumb != null
              r.img({src:album.thumb})

            r.close(2)
              .td({class: 'text-muted'}).esc(share)
              .close(2)
 
          r.show()
        
      .show()

    
