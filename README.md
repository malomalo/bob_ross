# Bob Ross

A Rack Image Server to mulipulate images.


## Installation

BobRoss depends on the following:

  - `ruby`
  - `imagemagick`

Optionally:

  - `libwebp` to support the [WEBP](https://en.wikipedia.org/wiki/WebP) image
    format
  - `jxrlib` to support the [JPEG XR](https://en.wikipedia.org/wiki/JPEG_XR)
    image format

# Client (Generating URLs)

The BobRoss client makes it easy to generate urls for requesting the server.

For example to generate a path that resizes an image to 100x100:

`BobRoss.path('hash', resize: '100x100') #=> '/S100x100/hash'` 

In addition there is also a `url` helper if you have configured the host:

```ruby
BobRoss.host = 'https://example.com'
BobRoss.url('hash', resize: '100x100') #=> 'https://example.com/S100x100/hash'
```

### Available Options

- `:background` Set the background color of an image; Given in RGB or RGBA in
  Hex format
- `:crop` Crop the image after any other tranformations.
- `:expires` The time the URL will be expired and no longer valid. Should be used
  with an HMAC to prevent simply chaning the URL
- `:grayscale` When set to true will make the image grayscale
- `:hmac`
  - When set to `true` performs an hmac using the `:transformations` and `:hash`
    parts of the generated path
  - Can be set to an array containing any of the following and will use those
    fields to hmac the path:
      - `:transformations`
      - `:hash`
      - `:format`
- `:interlace` Progressively encode / Interlace the image
- `:lossless` When set to true the server will choose a lossless encoding and
  losslessly encode the image
- `:optimize` Optimizes the image in the following ways:
  - Strips the image of any profiles, comments, or vairous PNG chunks
  - Converts the image to the sRGB Color profile
  - Set's the quality/compression to 85%
- `:resize` See section under "Querying" for valid resize options
- `:transparent`
- `:watermark`

### Client Configuration

```ruby
BobRoss.defaults = {

	# Required if generating urls (not paths)
	host: 'https://example.com',
	
	# Required if signing paths/urls
	hmac: {
	
		# The secret to sign with
		key: 'secret',
		
		# The attributes to use when creating the HMAC
		attributes: [:transformations, :hash]
	}
	
	hmac: 'secret',
	
	# Any other options you wish to apply by default
}
```

# Server

BobRoss::Server is Rack Middleware that can be served on it's own or mounted on
any Rack compatiable server.

### Running the Server

Rails example:

```ruby
Rails.application.routes.draw do
  mount BobRoss::Server.new(bob_ross_configs), at: "/images"
end
```

### Configuration

```ruby
bob_ross_configs = {

  # (Required) A Module or Class instance that must respond to `local?`,
  # `last_modified` (if use_last_modified_header), `destination` (if local?),
  # and `copy_to_tempfile` (if !local?)
  store: my_store,
  
  # (Optional) Limit for max memory that image magick will use
  memory_limit: '1G',
  
  # (Optional) Limit for max disk that image magick will use
  disk_limit: '4G',
  
  # (Optional)
  hmac: {
    # Required if using signed paths/urls
    key: 'secret',
    
    # If true the server will respond with a 404 not found to any urls that
    # are not signed or incorrectly signed
    required: true || false,
    
    # All the allowed ways to sign the url
    attributes: [[:transformations], [:transformations, :hash, :format]]
  },

  # If using watermark(s), the path to the watermark(s)
  watermarks: ["/app/assets/images/watermark.png"]

  # Cache header to return with all valid responses
  cache_control: 'public, max-age=172800, immutable',
  
  last_modified_header: true || false
}
```

### Automatic Content Negotiation

#### Format

If no format is specified BobRoss will choose the first format that matches the
request from this list:

 - `webp` will be served if the `Accept` header includes `image/webp`
 - `jxr` if the `Accept` header includes `image/vnd.ms-photo`
 - `jpeg` if the image does not contain transparency and the `L` option
   (losslessly encode) is not selected
 - `png`

#### DPR

If the request contains the `DPR` header (see [Client Hints](http://caniuse.com/#feat=client-hints-dpr-width-viewport))
and a size is specified BobRoss will multiply the dimensions by the `DPR` value
to produce an appropriately sized image for the display; retina or otherwise.
BobRoss will return the image with the `Content-DRP` header.

### Querying

Below are valid BobRoss urls:

  - `/hash`
  - `/hash.format`
  - `/hash/filename`
  - `/hash/filename.format`
  - `/transformations/hash`
  - `/transformations/hash.format`
  - `/transformations/hash/filename`
  - `/transformations/hash/filename.format`

The __`hash`__ part of the URL is always lowercase and used to lookup the original
image file.

The __`format`__ is the image format, valid formats and extensions:

  - [JPEG XR](https://en.wikipedia.org/wiki/JPEG_XR): `jxr`
  - [JPEG](https://en.wikipedia.org/wiki/JPEG): `jpg` or `jpeg`
  - [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics): `png`
  - [WEBP](https://en.wikipedia.org/wiki/WebP): `webp`

The __`filename`__ is the URL Encoded filename you want the image named as.

The __`transformations`__ is composed of the following avaiable transformations
that can be performed on the image. The options are alphabetically sorted with
the exception of the `H` (HMAC option) which always comes first.

  - `Brrggbbaa` Sets the background color, defaults to `00000000`

  - `C{geometry}{offset}` Crops the image to the specified geometry where
    geometry is:

      - `width` - Width given, height automatically set to image height.
      - `xheight` - Height given, width automatically set to image width.
      - `widthxheight` - Width & Height explicitly given.

      And offset is:

      - `{+-}x{+-}y` Can be appended to any geometry to set the horizontal
        and vertical offsets `x` and `y`, specified in pixels. Signs are
        required for both. Offsets are not affected by % or other size
        operators. Default is `+0+0`

  - `E5772bd72` Sets the expiration of the link. The value is the current time in
    seconds, hex encoded. Once the specified time has passed the server will
    return a `410 Gone` HTTP status code.

  - `G` Converts the image to Grayscale

  - `H62c9c35e70316e7e828bd70df283e3f1d9eb905aB505153` The SHA1 HMAC of any
    of combination of the `format`, `hash`, and `transformations` sorted
    alphabetically signed with a shared secret. The server can be configured
    to only accept certain combinations.

  - `I` Interlace or Progressively encodes the image
  !!! Place interlace, should look at Line interlacing
  
  - `L` Losslessly encode images.

  - `O` - Optimize the image for delivery
    - Strips the image of any profiles, comments or any of the following PNG
      chunks: bKGD, cHRM, EXIF, gAMA, iCCP, iTXt, sRGB, tEXt, zCCP, zTXt, date
    - Converts the image to the sRGB Color profile
    - Removes any progressive/interlaced encoding unless the `I` (interlace)
      option is set.
      !!! UNLESS jpg! need to do
    - Set's the quality/compression to 85 for JPEG, and PNG

  - `P{top},{left},{bottom},{right}` - Adds N pixels of padding to the image,
    interperted like the CSS padding statement.
  
  - `S{geometry}` Resize the image to the specified geometry where the geometry is:

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

  - `T` Choose a format that supports transparency

  - `W{id}{gravity}{geometry}` Add a watermark to the image

    - `id` A decimal encoding integer represting the id of the watermark
      configured on the server
    - `gravity` Where to place the watermark on the image. Valid options are:
      - `c` for Center
      - `n` for North
      - `ne` for North East
      - `e` for East
      - `se` for South East
      - `s` for South
      - `sw` for South West
      - `w` for West
      - `nw` for North West
    - `geometry` The geometry of the watermark on the image (see above),
      including the following options:
      - `scale%`
      - `scale-x%xscale-y%`
      - `area@`
      - `{+-}x{+-}y` Can be appended to any geometry to set the horizontal
        and vertical offsets `x` and `y`, specified in pixels. Signs are
        required for both. Offsets are not affected by % or other size
        operators. Default is `+0+0`
