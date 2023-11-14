# Bob Ross

A Rack Image Server to mulipulate images.


## Installation

The BobRoss client does not have any dependencies.

The BobRoss server depends on the following:

  - `imagemagick` or `libvips`

Optionally:

  - `libheif` to support the [HEIC](https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format)
    and [AVIF](https://en.wikipedia.org/wiki/AVIF) image formats.
  - `libwebp` to support the [WEBP](https://en.wikipedia.org/wiki/WebP) image
    format.
  - `libjxl` to support the [JPEG XL](https://en.wikipedia.org/wiki/JPEG_XL)
    image format.
  - `OpenJPEG` to support the [JPEG 2000](https://en.wikipedia.org/wiki/JPEG_2000) image format.
  - `giflib` for GIF support in LibVips.
  - `libjpeg-turbo` for faster JPEG encoding/decoding.
  - The `sqlite3` gem to use a local disk cache.
  - `mupdf-tools` for PDF support

## Client (Generating URLs)

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
BobRoss.configure({

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

  # Default is 'libvips', you can also pass the class of another backend to use
  backend: 'imagemagick',

  # Any other options you wish to apply by default
})
```

## Server

BobRoss::Server is Rack Middleware that can be served on it's own or mounted on
any Rack compatiable server.

### Running the Server

Rails example:

```ruby
Rails.application.routes.draw do
  mount BobRoss::Server.new(bob_ross_configs), at: "/images"
end
```

### Configuration Options

- `store:` (Required) A Module or Class instance that must respond to `local?`,
           `last_modified` (if `last_modified_header` is set to true),
           `destination` (if local?), and `copy_to_tempfile` (if !local?)

- `backend:` (Optional, default `libvips`) `imagemagick` or `libvips`
- `memory_limit:` (Optional, ie. `"1GB"`) Limit for max memory that imagemagick will use.
- `disk_limit:` (Optional, ie. `"4GB"`) Limit for max disk that image magick will use
- `hmac:` (Optional)
  - `key:` (ie. `"secret"`) The secret key used for signing paths/urls
  - `required:` (true || false) If true the server will respond with a 404 not
                found to any urls that are not signed or incorrectly signed
  - `attributes:` (ie. `[[:transformations], [:transformations, :hash, :format]]`) 
                  All the allowed ways to sign the url.
  - `transformations:`
    - `optional:` Transformations that can be ignored when signing the HMAC.
                  (ie. [:resize, :grayscale])
- `watermarks:` (Optional, ie. `["/app/assets/images/watermark.png"]`) If using 					watermark(s), the path to the watermark(s).

- `cache_control:` (Optional, ie. `'public, max-age=172800, immutable'`)
                   Cache header to return with all valid responses

- `last_modified_header:` (true || false) Weather to use the `Last-Modified`
                          header or not
                          
- `cache:` (Optional) Config for the cache (optionally set to true).

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
that can be performed on the image. If an HMAC is sent the the `H` (HMAC option)
should always comes first.

  - `Brrggbb[aa]` Sets the background color, defaults to `00000000`

  - `C{geometry}{offset_or_func_or_gravity}` Crops the image to the specified geometry where
    geometry is:

      - `width` - Width given, height automatically set to image height.
      - `xheight` - Height given, width automatically set to image width.
      - `widthxheight` - Width & Height explicitly given.

      And `offset_or_func_or_gravity` is one of the following (default is `c`):

      - `{+-}x{+-}y` Can be appended to any geometry to set the horizontal
        and vertical offsets `x` and `y`, specified in pixels. Signs are
        required for both. Offsets are not affected by % or other size
        operators.
      - `gravity` Gravity, options listed below
	  - `sm` Smart crop, looks for features likely to draw human attention

  - `E5772bd72` Sets the expiration of the link. The value is the current time in
    seconds, hex encoded. Once the specified time has passed the server will
    return a `410 Gone` HTTP status code.

  - `G` Converts the image to Grayscale

  - `H62c9c35e70316e7e828bd70df283e3f1d9eb905aB505153` The SHA1 HMAC of any
    of combination of the `format`, `hash`, and `transformations` signed with a
    shared secret. The server can be configured to only accept certain combinations.

  - `I` Interlace or Progressively encode the image

  - `L` Losslessly encode images.

  - `O` - Optimize the image for delivery
    - Strips the image of any profiles, comments or any of the following PNG
      chunks: bKGD, cHRM, EXIF, gAMA, iCCP, iTXt, sRGB, tEXt, zCCP, zTXt, date
    - Converts the image to the sRGB Color profile
    - Removes any progressive/interlaced encoding unless the `I` (interlace)
      option is set.
      !!! UNLESS jpg! need to do
    - Set's the quality/compression to 85 for JPEG, and PNG

  - `P{top},{left},{bottom},{right}[rrggbb[aa]]` - Adds N pixels of padding to the image,
    interperted like the CSS padding statement, optionally followed by a `w` and the RGB(a)
    color to use for the padding.
  
  - `S{geometry}{gravity}[p{rrggbb[aa]}]` Resize the image to the specified geometry where the geometry is:

    - `width` - `resize_to_height`, resize the image to given width, height
      automatically selected to preserve aspect ratio.
    - `xheight` - `resize_to_height`, resize the image to given height, width
      automatically selected to preserve aspect ratio.
    - `widthxheight` - `resize_to_fit`, resize the image to fit within the given
      dimensions while preserving the aspect ratio.
    - `widthxheight!` - `resize`, resize the image to the dimensions ignoring the
      aspect ration.
    - `widthxheight>` - `resize_down`, shrink an image with dimension(s) larger
      than the corresponding width or height.
    - `widthxheight<` - `resize_up`, enlarge an image with dimension(s) smaller
      than the corresponding width or height.
    - `widthxheight#` - `resize_to_fit`, resize the image to fit within the
      specified dimensions while preserving the original aspect ratio. The image
      may be shorter or narrower than specified and is positioned according to
      the given gravity (default: centered) and a color (default: transparent black)
      is applied to meet the given dimensions.
    - `widthxheight*` - `resize_to_fill`, resize and fit/crop the image within
      the specified dimensions while preserving the aspect ratio of the original
      image. If necessary, crop the image to cover the area.
      
    Gravity is on of the following:

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

    p is the color to use on the edges with `#`, defaults to '#00000000'

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

  - `Q{quality}` Set the Q-factor for saving the image (1-100; 100 being best quality)

  - `R{quality}` Remove any metadata from the image

### The Disk Cache

The local disk cache that is shared across processes. It uses a sqlite3 file to
store and share which files are cached. This file should be stored on the local
filesystem. The cache files themselves can be on a local FS or a NFS.

Example:

```ruby
BobRoss::Cache.new('/mnt/cache_dir', '/srv/images/bobross_cache.sqlite3')
```

By default the size of the cache is only 1GB, you can set that by setting the
number of bytes you want the cache to be:

```ruby
BobRoss::Cache.new('/mnt/cache_dir', '/srv/images/bobross_cache.sqlite3', size: 10_737_418_240)
```

## Rails

If BobRoss is used with a Rails application it automatically sets up defatuls for
the client and attaches a server at `/images` by default.

### Initializer options

**`config.bob_ross.host`**

Host used for generating URL.

**`config.bob_ross.hmac.key`**

The secret key used by both the server and the client to generate and verify HMAC.

**`config.bob_ross.hmac.required`**

Weather or not an HMAC is requried when serving an image. By default this is true if
there is a HMAC key present, false otherwise.

**`config.bob_ross.hmac.attributes`**

The attributes used to generate the HMAC. By default BobRoss only uses the `:transformations` and `:hash` of the URL (`[:transformations, :hash]`). You can set
this to any combination of `:transformations`, `:hash`, and `:format`.

If you want to accept multiple types of HMAC on the server set this to an array of
HMAC you want to accept. For example:

```ruby
config.bob_ross.hmac.attributes = [
  [:transformations, :hash, :format],
  [:hash, :format]
]
```

When this is option is set this way the client will use the first option as the 
default when generating HMACS.

**`config.bob_ross.server`**

Set this to `false` to disable the server.

**`config.bob_ross.server.store`**

Where to original files are stored. This can be a Proc or the value itself.
There is no default and this must be specified. See the `store:` option in the server section for more information.

**`config.bob_ross.server.prefix`**

The prefix to use when serving images. Default is `"/images"`
  
**`config.bob_ross.server.cache_control`**

Set this to the value of the `Cache-Control` header if you want one.

**`config.bob_ross.server.last_modified_header`**

If you want BobRoss to send the `Last-Modified-Header` set this to false.

**`config.bob_ross.server.disk_limit`**

Limit the disk map used by imagemagick to transform an image. Default `"4GB"`

**`config.bob_ross.server.memory_limit`**

Limit the memory used by imagemagick to transform an image. Default `"1GB"`

**`config.bob_ross.server.cache`**

If set to false the cache will be disabled. Default in **`production`** is
*`false`*.

**`config.bob_ross.server.cache.file`**

The SQLite3 database used by BobRoss to keep stats about the cache.
Default is `"tmp/cache/bobross.cache"`

**`config.bob_ross.server.cache.path`**

Where to cache the transformed images. Default is `"tmp/cache/bobross"`

**`config.bob_ross.server.cache.size`**

Amount of disk size in bytes to use for the cache. Default is `1.gigabyte`

## Plugins

BobRoss can process any image format that ImageMagick or LibVips accepts.

To process other types of files and turn them into images that BobRoss can create a plugin.

For an example see `lib/bob_ross/plugins/pdf`.