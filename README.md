This project is based on https://github.com/luapower/libjpeg

---
tagline: JPEG encoding & decoding
---

# Requirement Library
[luapower-glue](https://github.com/luapower/glue)

[luapower-fs](https://github.com/luapower/fs)

[libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo) (v8 API)

## `local libjpeg = require('resty.libjpeg.jpeg')`

A ffi binding for the [libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo) v8 API.
Supports progressive loading, yielding from the reader function,
partial loading, fractional scaling and multiple pixel formats.

## API

------------------------------------ -----------------------------------------
  * `libjpeg.load_blob(blob) -> img:`     open a JPEG image from blob binary data for decoding
  * `img.compress.[opt]:`                 set/read option for compress process (must set before run get_blob() for save() function)
  * `img.bmp:`                            (readonly) the bitmap object after decompress
  * `img:get_blob():`                     get JPEG image to binary string after compress
  * `img:save():`                         save JPEG image to disk (must set img.compress.outfile)
  * `img:free():`                         free the image
------------------------------------ -----------------------------------------

### `libjpeg.load_blob(blob) -> img`

Open a JPEG image and read its header. `blob` is whole image binary string

The return value is an image object which gives information about the file
and can be used to load and decode the actual pixels. It has the fields:

  * `w`, `h`: width and height of the image.
  * `format`: the format in which the image is stored.
  * `progressive`: `true` if it's a progressive image.
  * `jfif`: JFIF marker (see code).
  * `adobe`: Adobe marker (see code).
  * `partial`: true if the image was found to be truncated and it was
  partially loaded (this may become `true` after loading the image).

__NOTE:__ Unknown JPEG formats are opened but the `format` field is missing.

### `img.compress.[opt]`

Set settings for compress process. `opt` are some options as follow:

  * `outfile<string>`: path to file on disk to save.
  * `format<string>`: output format (see list of supported formats below).
  * `quality<int>`: `0..100` range. you know what that is.
  * `progressive`: `true/false` (default is `false`). make it progressive.
  * `dct_method`: `'accurate'`, `'fast'`, `'float'` (default is `'accurate'`).
  * `optimize_coding`: optimize huffmann tables.
  * `smoothing<int>`: `0..100` range. smoothing factor.
  * `write_buffer_size<int>`: internal buffer size (default is 131072).

### `img.bmp`

Attribute store image data after decompress process


### `img:get_blob() -> return <string> binaray data`

Get image data in binary string after compress process


### `img:save()`

Save image to disk base on img.compress.outfile setting


### `img:free()`

Free the image and associated resources.

#### Format Conversions

------------------- ----------------------------------------------------------
__source formats__  __destination formats__

`ycc8`, `g8`        `rgb8`, `bgr8`, `rgba8`, `bgra8`, `argb8`, `abgr8`,
                    `rgbx8`, `bgrx8`, `xrgb8`, `xbgr8`, `g8`

`ycck8`             `cmyk8`
------------------- ----------------------------------------------------------

__NOTE__: As can be seen, not all conversions are possible with libjpeg-turbo,
so always check the image's `format` field to get the actual format. Use
[bitmap](https://luapower.com/bitmap) to further convert the image if necessary.

__NOTE:__ the number of bits per channel in the output bitmap is always 8.


## Sample Code

Nginx Configuration

~~~~ config
server {
	listen 80;
	location = /favicon.ico {
		empty_gif;
	}
	location ~ /proxy(.*) {
	    ## can use root or proxy_pass to get data from local or remote site
		# proxy_pass https://<origin>$1;
		root /dev/shm;
	}
	location / {
		content_by_lua_file resty-libjpeg-sample.lua;
	}
}
~~~~

resty-libjpeg-sample.lua

~~~~ lua

local libjpeg = require("resty.libjpeg.jpeg") -- load library
local res = ngx.location.capture('/proxy'..ngx.var.request_uri) -- get data from nginx location /proxy by subrequest 
local img = libjpeg.load_blob(res.body) -- create object im
local outfile = '/dev/shm/proxy/inputhd_new.jpg' -- declare outfile path
img.compress.outfile = outfile -- set outfile setting
img.compress.format = "g8" -- set format setting (g8 = Grayscale)
img.compress.quality = 80 -- set quality
img:save() -- save file to disk
ngx.print(img:get_blob()) -- return image after compress to end user
~~~~
