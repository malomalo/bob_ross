# Bob Ross

A Rack Image Server.

# Dependencies

 - `ruby` 2.3?
 - `imagemagick`

# Optional Dependencies

 - `webp`, libwebp
 - `jxrlib`

# Ruby Client

## configuration

```ruby
BobRoss.configure do
  host:
  hamc:
  defaults:
end
```

## Generating URLs

# Server

## Configuration

```ruby
BobRoss.configure do
  hmac: {required: , key: , data: }
  watermarks: [...]
  disk_limit:
  memory_limit:
  store
end
```

## Running the Server

### Automatic Content Negotiation

#### Format

If no format is specified BobRoss will choose the first format that matches the request from this list:

 - `webp` will be served if the `Accept` header includes `image/webp`
 - `jxr` if the `Accept` header includes `image/vnd.ms-photo`
 - `jpeg` if the image does not contain transparency and the `L` option
   (losslessly encode) is not selected
 - `png`

#### DPR

If the request contains the `DPR` header (see [Client Hints](http://caniuse.com/#feat=client-hints-dpr-width-viewport)) and a size is specified BobRoss will multiply the dimensions by the `DPR` value to produce an appropriately sized image for the display; retina or otherwise. BobRoss will return the image with the `Content-DRP` header.

### Querying

* `Brrggbbaa` Sets the background color, defaults to `00000000`

* `E5772bd72` Sets the expiration of the link. The value is the current time in
  seconds, hex encoded. Once the specified time has passed the server will
  return a `410 Gone` HTTP status code.

!! Need to add to server

* `G` Converts the image to Grayscale

* `H62c9c35e70316e7e828bd70df283e3f1d9eb905aB505153` The SHA1 HMAC of any
  of combination of the `format`, `hash`, and `transformations` sorted
  alphabetically signed with a shared secret. The server can be configured
  to only accept certain combinations.

!! need to sort on server/client also define tranformations

* `L` Losslessly encode images.

* `O` - Optimize the image for delivery
  * Strips the image of any profiles, comments or any of the following PNG
    chunks: bKGD, cHRM, EXIF, gAMA, iCCP, iTXt, sRGB, tEXt, zCCP, zTXt, date
  * Converts the image to the sRGB Color profile
  * Removes any progressive/interlaced encoding unless the `P` (progressive)
    option is set.
    !!! UNLESS jpg! need to do
  * Set's the quality/compression to 85 for JPEG, and PNG

* `P` Interlace or Progressively encodes the image
  !!! Place interlace, should look at Line interlacing

* `S{geometry}` Resize the image to the specified geometry where the geometry is:

    - `width` - Width given, height automatically selected to preserve aspect
      ratio.
    - `xheight` - Height given, width automatically selected to preserve aspect
      ratio.
    - `widthxheight` - Maximum values of height and width given, aspect ratio
      preserved
    - `widthxheight^` - Minimum values of width and height given, aspect ratio
      preserved.
    - `widthxheight!` - Width and height emphatically given, original aspect
      ratio ignored.
    - `widthxheight>` - Shrinks an image with dimension(s) larger than the
      corresponding width and/or height argument(s).
    - `widthxheight<` - Enlarges an image with dimension(s) smaller than the
      corresponding width and/or height argument(s).
    - `widthxheight#` - Width and height given, image fit to be contained by
      deminsions while perserving aspect ratio. Image is centered vertically
      and horizontally and a background color is applied.
    - `widthxheight*` - Width and height given, image fit/croped to cover the
      deminsions while perserving aspect ratio. Image is centered vertically
      and horizontally

* `T`

identify -format '%[opaque]' file => true is no tranparency

* `W{id}{gravity}{geometry}` W0se

  - `id` A decimal encoding integer represting the id of the watermark
    configured on the server
  - `gravity` Where to place the watermark on the image. Valid options are:
      * `c` for Center
      * `n` for North
      * `ne` for North East
      * `e` for East
      * `se` for South East
      * `s` for South
      * `sw` for South West
      * `w` for West
      * `nw` for North West
  - `geometry` The geometry of the watermark on the image (see above),
    including the following options:
      * `scale%`
      * `scale-x%xscale-y%`
      * `area@`
      * `{+-}x{+-}y` Can be appended to any geometry to set the horizontal
        and vertical offsets `x` and `y`, specified in pixels. Signs are
        required for both. Offsets are not affected by % or other size
        operators. Default is `+0+0`
