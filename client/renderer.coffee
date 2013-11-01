# Renderers are used to build entire pages.
#
# They keep an internal array of HTML segments that are concatenated when
# rendering, as well as a list of tags "to be ended" for convenience. 

@R = (@$) ->
  @h = []
  @e = []
  @c = {}
  @
    
do ->
  
  n = 0

  R.prototype =

    # Renders the contents of the renderer to the
    # main container of the page. If any tags are left
    # unclosed, closes them.
  
    show: ->
      [].push.call @h, @e
      @$.html @h.join ''
      @c[k] new R $ k for k of @c
             
    # Renders HTML-escaped text.

    esc: (t) ->
      @h.push $('<div/>').text(t).html()
      @

    # Renders the initial segment of a tag.
    # Used internally by `open` and `tag`
  
    st: (t,a,f) ->
      @h.push '<', t
      for k, v of a || {}
        @h.push ' ', k, '="'
        @esc v
        @h.push '"'
      if f
        id = '_' + ++n
        @c['#' + id] = f
        @h.push ' id=', id
      
    # Renders an opening tag, stores the closing tag for later.

    open: (t,a,f) ->
      @st t, a, f
      @h.push '>'
      @e.unshift ('</'+t+'>')
      @
      
    # Closes one (or several) previously opened tags.

    close: (n=1) ->
      @h.push @e.shift() while n-- > 0
      @
      
    # Renders a self-closing tag

    tag: (t,a,f) ->
      @st t, a
      @h.push '/>'
      @

  # Add definitions for common tags.

  tag = (sc,t) ->
    k = arguments
    R.prototype[t] = (a,f) ->
      if sc
        @tag t, a, f
      else
        @open t, a, f 

  for t in [ "a", "span", "div", "td", "tr", "table", "button", "h1", "h2", "h3", "h4", "h5", "h6", "textarea", "label", "form", "p", "thead", "tbody" ]
    tag false, t

  for t in [ "img", "input" ]
    tag true, t

  
