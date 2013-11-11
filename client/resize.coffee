@resize = (id,img,albumP,next) ->

  return next null if albumP.access != 'PUT'

  maxH = Gallery.prototype.maxHeight
  maxW = Gallery.prototype.maxWidth
  w = img.naturalWidth
  h = img.naturalHeight
  ratio = w / h
  if w > maxW
    w = maxW
    h = w / ratio
  if h > maxH
    h = maxH
    w = h * ratio

  canvas = $('<canvas>')[0]
  canvas.width  = w
  canvas.height = h
  ctx = canvas.getContext '2d'
  ctx.drawImage img, 0, 0, w, h
  base64 = canvas.toDataURL('image/jpeg').substring 'data:image/jpeg;base64,'.length 

  Albums.proof "", albumP.id, (albumP) ->
    return unlock() if albumP == null || albumP.access != 'PUT'
    lock (unlock) ->
      payload = { album: albumP, picture: id, thumb: base64 }
      API.post "album/thumbnail", payload, (r) ->
        next r.picture
        unlock()
