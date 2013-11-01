# Displaying album pages.

"/".route (r) ->

  r.table({class:"table album"})

    .thead().tr().td({colspan:3}).h2().esc("Albums")
    .close(4)

    .tbody {}, (r) ->

      r.tr()
        .td().esc("A").close()
        .td().esc("B").close()
        .td().esc("C").close()
        .show()
        
    .show()

    
