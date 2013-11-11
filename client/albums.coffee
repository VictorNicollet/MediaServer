# Displaying album pages.

do ->

  # True if the user has administration rights on the albums.

  isAdmin = false

  # The list-of-all-albums model.

  @Albums = new List (l,next) ->
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

        Albums.all '', (l) ->

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

  # The list-of-pics-in-album model.
  @Pictures = new List (l,next) ->
    lock (unlock) ->
      post "album/pictures", l, (r) ->
        next r.pictures
        unlock()

  "/album/*".route (r, id) ->
    Albums.get "", id, (album) -> 
      if album.id.access = 'PUT' 
        r.p({class:'pull-right text-mute'}).esc('Drop pictures here to upload them').close()
      r.h3().esc(album.name).close()
      r.div {}, (r) -> 

        Albums.proof "", id, (proof) ->
          Pictures.all proof, (all) ->
            if all.length == 0
              r.div({id:"empty",class:'well empty'}).text('No pictures in this album')
              .show()
            else
              gallery r, proof, (g) -> 
                g.add pic for pic in all 
                return
                
      r.show()
