
--libjpeg ffi binding.
--Written by Cosmin Apreutesei. Public domain.
--Modified by Luan Vo - 20190531

local ffi = require'ffi'
local bit = require'bit'
local glue = require'glue'
local C = require ("resty.libjpeg.lib")

local LIBJPEG_VERSION = 80

--NOTE: images with C.JCS_UNKNOWN format are not supported.
local formats = {
	[C.JCS_GRAYSCALE]= 'g8',
	[C.JCS_YCbCr]    = 'ycc8',
	[C.JCS_CMYK]     = 'cmyk8',
	[C.JCS_YCCK]     = 'ycck8',
	[C.JCS_RGB]      = 'rgb8',
	--libjpeg-turbo only
	[C.JCS_EXT_RGB]  = 'rgb8',
	[C.JCS_EXT_BGR]  = 'bgr8',
	[C.JCS_EXT_RGBX] = 'rgbx8',
	[C.JCS_EXT_BGRX] = 'bgrx8',
	[C.JCS_EXT_XRGB] = 'xrgb8',
	[C.JCS_EXT_XBGR] = 'xbgr8',
	[C.JCS_EXT_RGBA] = 'rgba8',
	[C.JCS_EXT_BGRA] = 'bgra8',
	[C.JCS_EXT_ARGB] = 'argb8',
	[C.JCS_EXT_ABGR] = 'abgr8',
}

local channel_count = {
	g8 = 1, ycc8 = 3, cmyk8 = 4, ycck8 = 4, rgb8 = 3, bgr8 = 3,
	rgbx8 = 4, bgrx8 = 4, xrgb8 = 4, xbgr8 = 4,
	rgba8 = 4, bgra8 = 4, argb8 = 4, abgr8 = 4,
}

local color_spaces = glue.index(formats)

--all conversions that libjpeg implements, in order of preference.
--{source = {dest1, ...}}
local conversions = {
	ycc8 = {'rgb8', 'bgr8', 'rgba8', 'bgra8', 'argb8', 'abgr8', 'rgbx8',
		'bgrx8', 'xrgb8', 'xbgr8', 'g8'},
	g8 = {'rgb8', 'bgr8', 'rgba8', 'bgra8', 'argb8', 'abgr8', 'rgbx8', 'bgrx8',
		'xrgb8', 'xbgr8'},
	ycck8 = {'cmyk8'},
}

local bufInfo = {
	read = nil,
	bytes_to_skip = 0,
	buf = 0,
	sz = 0,
	partial_loading = nil
}
--given current pixel format of an image and an accept table,
--choose the best accepted pixel format.
local function best_format(format, accept)
	if not accept or accept[format] then --no preference or source format accepted
		return format
	end
	if conversions[format] then
		for _,dformat in ipairs(conversions[format]) do
			if accept[dformat] then --convertible to the best accepted format
				return dformat
			end
		end
	end
	return format --not convertible
end

--given a row stride, return the next larger stride that is a multiple of 4.
local function pad_stride(stride)
	return bit.band(stride + 3, bit.bnot(3))
end

--create a callback manager object and its destructor.
local function callback_manager(mgr_ctype, callbacks)
	local mgr = ffi.new(mgr_ctype)
	local cbt = {}
	for k,f in pairs(callbacks) do
		if type(f) == 'function' then
			cbt[k] = ffi.cast(string.format('jpeg_%s_callback', k), f)
			mgr[k] = cbt[k]
		else
			mgr[k] = f
		end
	end
	local function free()
		for k,cb in pairs(cbt) do
			mgr[k] = nil --anchor mgr
			cb:free()
		end
	end
	return mgr, free
end

--end-of-image marker, inserted on EOF for partial display of broken images.
local JPEG_EOI = string.char(0xff, 0xD9):rep(32)

local dct_methods = {
	accurate = C.JDCT_ISLOW,
	fast = C.JDCT_IFAST,
	float = C.JDCT_FLOAT,
}

local ccptr_ct = ffi.typeof'const uint8_t*' --const prevents copying

--create and setup a error handling object.
local function jpeg_err(t)
	local jerr = ffi.new'jpeg_error_mgr'
	C.jpeg_std_error(jerr)
	local err_cb = ffi.cast('jpeg_error_exit_callback', function(cinfo)
		local buf = ffi.new'uint8_t[512]'
		cinfo.err.format_message(cinfo, buf)
		error(ffi.string(buf))
	end)
	local warnbuf --cache this buffer because there are a ton of messages
	local emit_cb = ffi.cast('jpeg_emit_message_callback', function(cinfo, level)
		if t.warning then
			warnbuf = warnbuf or ffi.new'uint8_t[512]'
			cinfo.err.format_message(cinfo, warnbuf)
			t.warning(ffi.string(warnbuf), level)
		end
	end)
	local function free() --anchor jerr, err_cb, emit_cb
		C.jpeg_std_error(jerr) --reset jerr fields
		err_cb:free()
		emit_cb:free()
	end
	jerr.error_exit = err_cb
	jerr.emit_message = emit_cb
	return jerr, free
end

--create a top-down or bottom-up array of rows pointing to a bitmap buffer.
local function rows_buffer(h, bottom_up, data, stride)
	local rows = ffi.new('uint8_t*[?]', h)
	local data = ffi.cast('uint8_t*', data)
	if bottom_up then
		for i=0,h-1 do
			rows[h-1-i] = data + (i * stride)
		end
	else
		for i=0,h-1 do
			rows[i] = data + (i * stride)
		end
	end
	return rows
end

local function fill_input_buffer(cinfo,img)
	if bufInfo["bytes_to_skip"] > 0 then
		bufInfo["read"](nil, bufInfo["bytes_to_skip"])
		bufInfo["bytes_to_skip"] = 0
	end
	local ofs = tonumber(cinfo.src.bytes_in_buffer)
	--move the data after the restart point to the start of the buffer
	ffi.C.memmove(bufInfo["buf"], cinfo.src.next_input_byte, ofs)
	--move the restart point to the start of the buffer
	cinfo.src.next_input_byte = bufInfo["buf"]
	--fill the rest of the buffer
	local sz = bufInfo["sz"] - ofs
	assert(sz > 0, 'buffer too small')
	local readsz = bufInfo["read"](bufInfo["buf"] + ofs, sz)
	if readsz == 0 then --eof
		assert(bufInfo["partial_loading"], 'eof')
		readsz = #JPEG_EOI
		assert(readsz <= sz, 'buffer too small')
		ffi.copy(bufInfo["buf"] + ofs, JPEG_EOI)
		img.partial = true
	end
	cinfo.src.bytes_in_buffer = ofs + readsz
end

local function load_header(cinfo,img)

	while C.jpeg_read_header(cinfo, 1) == C.JPEG_SUSPENDED do
		fill_input_buffer(cinfo,img)
	end

	img.w = cinfo.image_width
	img.h = cinfo.image_height
	img.format = formats[tonumber(cinfo.jpeg_color_space)]
	img.progressive = C.jpeg_has_multiple_scans(cinfo) ~= 0

	img.jfif = cinfo.saw_JFIF_marker == 1 and {
		maj_ver = cinfo.JFIF_major_version,
		min_ver = cinfo.JFIF_minor_version,
		density_unit = cinfo.density_unit,
		x_density = cinfo.X_density,
		y_density = cinfo.Y_density,
	} or nil

	img.adobe = cinfo.saw_Adobe_marker == 1 and {
		transform = cinfo.Adobe_transform,
	} or nil
end

local function load_image(cinfo,img, t)

	local bmp = {}
	--find the best accepted output pixel format
	assert(img.format, 'invalid pixel format')
	assert(cinfo.num_components == channel_count[img.format])
	bmp.format = best_format(img.format, t and t.accept)

	--set decompression options
	cinfo.out_color_space = assert(color_spaces[bmp.format])
	cinfo.output_components = channel_count[bmp.format]
	cinfo.scale_num = t and t.scale_num or 1
	cinfo.scale_denom = t and t.scale_denom or 1
	local dct_method = dct_methods[t and t.dct_method or 'accurate']
	cinfo.dct_method = assert(dct_method, 'invalid dct_method')
	cinfo.do_fancy_upsampling = t and t.fancy_upsampling or false
	cinfo.do_block_smoothing = t and t.block_smoothing or false
	cinfo.buffered_image = 1 --multi-scan reading

	--start decompression, which fills the info about the output image
	while C.jpeg_start_decompress(cinfo) == 0 do
		fill_input_buffer(cinfo,img)
	end

	--get info about the output image
	bmp.w = cinfo.output_width
	bmp.h = cinfo.output_height

	--compute the stride
	bmp.stride = cinfo.output_width * cinfo.output_components
	if t and t.accept and t.accept.stride_aligned then
		bmp.stride = pad_stride(bmp.stride)
	end

	--allocate image and row buffers
	bmp.size = bmp.h * bmp.stride
	bmp.data = ffi.new('uint8_t[?]', bmp.size)
	bmp.bottom_up = t and t.accept and t.accept.bottom_up

	local rows = rows_buffer(bmp.h, bmp.bottom_up, bmp.data, bmp.stride)

	--decompress the image
	while C.jpeg_input_complete(cinfo) == 0 do

		--read all the scanlines of the current scan
		local ret
		repeat
			ret = C.jpeg_consume_input(cinfo)
			if ret == C.JPEG_SUSPENDED then
				fill_input_buffer(cinfo,img)
			end
		until ret == C.JPEG_REACHED_EOI or ret == C.JPEG_SCAN_COMPLETED
		local last_scan = ret == C.JPEG_REACHED_EOI

		--render the scan
		C.jpeg_start_output(cinfo, cinfo.input_scan_number)

		--read all the scanlines into the row buffers
		while cinfo.output_scanline < bmp.h do

			--read several scanlines at once, depending on the size of the output buffer
			local i = cinfo.output_scanline
			local n = math.min(bmp.h - i, cinfo.rec_outbuf_height)
			while C.jpeg_read_scanlines(cinfo, rows + i, n) < n do
				fill_input_buffer(cinfo,img)
			end
		end

		--call the rendering callback on the converted image
		if t and t.render_scan then
			t.render_scan(bmp, last_scan, cinfo.output_scan_number)
		end

		while C.jpeg_finish_output(cinfo) == 0 do
			fill_input_buffer(cinfo,img)
		end

	end

	while C.jpeg_finish_decompress(cinfo) == 0 do
		fill_input_buffer(cinfo,img)
	end

	return bmp
end

local function save(bmp,t)
	local write
	local allbuf = ""
	local f
	if t.outfile then
		--open file to write
		local fs = require('fs')
		f = assert(fs.open(t.outfile, 'w'))
		write =  function(buf, sz)
			assert(f:write(buf, sz) == sz)
		end
	else
		write =  function(buf, sz)
			allbuf = allbuf .. ffi.string(buf,sz)
		end
	end
	glue.fcall(function(finally)

		--create the state object
		local cinfo = ffi.new'jpeg_compress_struct'

		--setup error handling
		local jerr, jerr_free = jpeg_err(t)
		cinfo.err = jerr
		finally(jerr_free)

		--init state
		C.jpeg_CreateCompress(cinfo,
			t.lib_version or LIBJPEG_VERSION,
			ffi.sizeof(cinfo))

		finally(function()
			C.jpeg_destroy_compress(cinfo)
		end)

		local write = write
		local finish = t.finish or glue.pass

		--create the dest. buffer
		local sz = t.write_buffer_size or 4096
		local buf = t.write_buffer or ffi.new('char[?]', sz)

		--create destination callbacks
		local cb = {}

		function cb.init_destination(cinfo)
			cinfo.dest.next_output_byte = buf
			cinfo.dest.free_in_buffer = sz
		end

		function cb.term_destination(cinfo)
			write(buf, sz - cinfo.dest.free_in_buffer)
			finish()
		end

		function cb.empty_output_buffer(cinfo)
			write(buf, sz)
			cb.init_destination(cinfo)
			return true
		end

		--create a destination manager and set it up
		local mgr, free_mgr = callback_manager('jpeg_destination_mgr', cb)
		cinfo.dest = mgr
		finally(free_mgr) --the finalizer anchors mgr through free_mgr!

		--set the source format
		cinfo.image_width = bmp.w
		cinfo.image_height = bmp.h
		cinfo.in_color_space =
		assert(color_spaces[bmp.format], 'invalid source format')
		cinfo.input_components =
		assert(channel_count[bmp.format], 'invalid source format')

		--set the default compression options based on in_color_space
		C.jpeg_set_defaults(cinfo)

		--set compression options
		if t.format then
			C.jpeg_set_colorspace(cinfo,
				assert(color_spaces[t.format]))
		end
		if t.quality then
			C.jpeg_set_quality(cinfo, t.quality, true)
		end
		if t.progressive then
			C.jpeg_simple_progression(cinfo)
		end
		if t.dct_method then
			cinfo.dct_method =
			assert(dct_methods[t.dct_method], 'invalid dct_method')
		end
		if t.optimize_coding then
			cinfo.optimize_coding = t.optimize_coding
		end
		if t.smoothing then
			cinfo.smoothing_factor = t.smoothing
		end

		--start the compression cycle
		C.jpeg_start_compress(cinfo, true)

		--make row pointers from the bitmap buffer

		local rows = rows_buffer(bmp.h, bmp.bottom_up, bmp.data, bmp.stride)

		--compress rows
		C.jpeg_write_scanlines(cinfo, rows, bmp.h)

		--finish the compression, optionally adding additional scans
		C.jpeg_finish_compress(cinfo)
	end)
	if t.outfile then
		f:close()
		return true
	else
		return allbuf
	end
end

local function load_blob(blob)
	local t = {}
	--normalize args
	if type(t) == 'function' then
		t = {read = t}
	end

	--create a global free function and finalizer accumulator
	local free_t = {} --{free1, ...}

	local function free()
		if not free_t then return end
		for i = #free_t, 1, -1 do
			free_t[i]()
		end
		free_t = nil
	end

	local function finally(func)
		table.insert(free_t, func)
	end
	--create the state object and output image
	local cinfo = ffi.new'jpeg_decompress_struct'

	--image settings table
	local compressSettings = {
		write_buffer_size = 131072,
		format = nil,
		quality = nil,
		progressive = nil,
		dct_method = nil,
		optimize_coding = nil,
		smoothing = nil,
		outfile = nil
	}
	-- init img object
	local img = {
		compress = compressSettings
	}

	img.free = free

	--setup error handling
	local jerr, jerr_free = jpeg_err(t)
	cinfo.err = jerr
	finally(jerr_free)

	--init state
	C.jpeg_CreateDecompress(cinfo,
		t.lib_version or LIBJPEG_VERSION,
		ffi.sizeof(cinfo))

	finally(function()
		C.jpeg_destroy_decompress(cinfo)
		cinfo = nil
	end)

	ffi.gc(cinfo, free)

	C.jpeg_mem_src(cinfo, blob, #blob);

	local ok, err = pcall(function() load_header(cinfo,img) end )
	if not ok then
		free()
		return nil, err
	end

	img.bmp = load_image(cinfo,img,t)
	img.get_blob = function() img.settings.outfile = nil return save(img.bmp,img.settings) end
	img.save = function() return save(img.bmp,img.settings) end
	return img
end

return {
	load_blob = load_blob,
}
