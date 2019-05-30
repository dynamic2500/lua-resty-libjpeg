local _M = {name = "CLib_for_libjpeg"}
local ffi = require'ffi'

ffi.cdef[[
typedef int boolean;
typedef struct FILE FILE;

enum {
	JPEG_SUSPENDED,     /* Suspended due to lack of input data */
	JPEG_REACHED_SOS,   /* Reached start of new scan */
	JPEG_REACHED_EOI,   /* Reached end of image */
	JPEG_ROW_COMPLETED, /* Completed one iMCU row */
	JPEG_SCAN_COMPLETED /* Completed last iMCU row of a scan */
};
typedef short INT16;
typedef signed int INT32;
typedef unsigned char JSAMPLE;
typedef short JCOEF;
typedef unsigned char JOCTET;
typedef unsigned char UINT8;
typedef unsigned short UINT16;
typedef unsigned int JDIMENSION;
typedef JSAMPLE *JSAMPROW;
typedef JSAMPROW *JSAMPARRAY;
typedef JSAMPARRAY *JSAMPIMAGE;
typedef JCOEF JBLOCK[64];
typedef JBLOCK *JBLOCKROW;
typedef JBLOCKROW *JBLOCKARRAY;
typedef JBLOCKARRAY *JBLOCKIMAGE;
typedef JCOEF *JCOEFPTR;
typedef struct cjpeg_source_struct *cjpeg_source_ptr;

typedef struct {
	UINT16 quantval[64];
	boolean sent_table;
} JQUANT_TBL;

typedef struct {
	UINT8 bits[17];
	UINT8 huffval[256];
	boolean sent_table;
} JHUFF_TBL;

typedef struct {
	int component_id;
	int component_index;
	int h_samp_factor;
	int v_samp_factor;
	int quant_tbl_no;
	int dc_tbl_no;
	int ac_tbl_no;
	JDIMENSION width_in_blocks;
	JDIMENSION height_in_blocks;
	int DCT_scaled_size;
	JDIMENSION downsampled_width;
	JDIMENSION downsampled_height;
	boolean component_needed;
	int MCU_width;
	int MCU_height;
	int MCU_blocks;
	int MCU_sample_width;
	int last_col_width;
	int last_row_height;
	JQUANT_TBL * quant_table;
	void * dct_table;
} jpeg_component_info;

typedef struct {
	int comps_in_scan;
	int component_index[4];
	int Ss, Se;
	int Ah, Al;
} jpeg_scan_info;

typedef struct jpeg_marker_struct * jpeg_saved_marker_ptr;

struct jpeg_marker_struct {
	jpeg_saved_marker_ptr next;
	UINT8 marker;
	unsigned int original_length;
	unsigned int data_length;
	JOCTET * data;
};

typedef enum {
	JCS_UNKNOWN,
	JCS_GRAYSCALE,
	JCS_RGB,
	JCS_YCbCr,
	JCS_CMYK,
	JCS_YCCK,
	/* libjpeg-turbo only */
	JCS_EXT_RGB,
	JCS_EXT_RGBX,
	JCS_EXT_BGR,
	JCS_EXT_BGRX,
	JCS_EXT_XBGR,
	JCS_EXT_XRGB,
	JCS_EXT_RGBA,
	JCS_EXT_BGRA,
	JCS_EXT_ABGR,
	JCS_EXT_ARGB
} J_COLOR_SPACE;

typedef enum {
	JDCT_ISLOW,
	JDCT_IFAST,
	JDCT_FLOAT
} J_DCT_METHOD;

typedef enum {
	JDITHER_NONE,
	JDITHER_ORDERED,
	JDITHER_FS
} J_DITHER_MODE;

struct jpeg_common_struct {
  struct jpeg_error_mgr * err;
  struct jpeg_memory_mgr * mem;
  struct jpeg_progress_mgr * progress;
  void * client_data;
  boolean is_decompressor;
  int global_state;
};

typedef struct jpeg_common_struct * j_common_ptr;
typedef struct jpeg_compress_struct * j_compress_ptr;
typedef struct jpeg_decompress_struct * j_decompress_ptr;

typedef struct jpeg_compress_struct {
    struct jpeg_error_mgr *err;
  struct jpeg_memory_mgr *mem;
  struct jpeg_progress_mgr *progress;
  void *client_data;
  boolean is_decompressor;
  int global_state;           /* Fields shared with jpeg_decompress_struct */

  /* Destination for compressed data */
  struct jpeg_destination_mgr *dest;

  /* Description of source image --- these fields must be filled in by
   * outer application before starting compression.  in_color_space must
   * be correct before you can even call jpeg_set_defaults().
   */

  JDIMENSION image_width;       /* input image width */
  JDIMENSION image_height;      /* input image height */
  int input_components;         /* # of color components in input image */
  J_COLOR_SPACE in_color_space; /* colorspace of input image */

  double input_gamma;           /* image gamma of input image */

  /* Compression parameters --- these fields must be set before calling
   * jpeg_start_compress().  We recommend calling jpeg_set_defaults() to
   * initialize everything to reasonable defaults, then changing anything
   * the application specifically wants to change.  That way you won't get
   * burnt when new parameters are added.  Also note that there are several
   * helper routines to simplify changing parameters.
   */

  unsigned int scale_num, scale_denom; /* fraction by which to scale image */

  JDIMENSION jpeg_width;        /* scaled JPEG image width */
  JDIMENSION jpeg_height;       /* scaled JPEG image height */
  /* Dimensions of actual JPEG image that will be written to file,
   * derived from input dimensions by scaling factors above.
   * These fields are computed by jpeg_start_compress().
   * You can also use jpeg_calc_jpeg_dimensions() to determine these values
   * in advance of calling jpeg_start_compress().
   */

  int data_precision;           /* bits of precision in image data */

  int num_components;           /* # of color components in JPEG image */
  J_COLOR_SPACE jpeg_color_space; /* colorspace of JPEG image */

  jpeg_component_info *comp_info;
  /* comp_info[i] describes component that appears i'th in SOF */

  JQUANT_TBL *quant_tbl_ptrs[4];
  int q_scale_factor[4];
  /* ptrs to coefficient quantization tables, or NULL if not defined,
   * and corresponding scale factors (percentage, initialized 100).
   */

  JHUFF_TBL *dc_huff_tbl_ptrs[4];
  JHUFF_TBL *ac_huff_tbl_ptrs[4];
  /* ptrs to Huffman coding tables, or NULL if not defined */

  UINT8 arith_dc_L[16]; /* L values for DC arith-coding tables */
  UINT8 arith_dc_U[16]; /* U values for DC arith-coding tables */
  UINT8 arith_ac_K[16]; /* Kx values for AC arith-coding tables */

  int num_scans;                /* # of entries in scan_info array */
  const jpeg_scan_info *scan_info; /* script for multi-scan file, or NULL */
  /* The default value of scan_info is NULL, which causes a single-scan
   * sequential JPEG file to be emitted.  To create a multi-scan file,
   * set num_scans and scan_info to point to an array of scan definitions.
   */

  boolean raw_data_in;          /* TRUE=caller supplies downsampled data */
  boolean arith_code;           /* TRUE=arithmetic coding, FALSE=Huffman */
  boolean optimize_coding;      /* TRUE=optimize entropy encoding parms */
  boolean CCIR601_sampling;     /* TRUE=first samples are cosited */
  boolean do_fancy_downsampling; /* TRUE=apply fancy downsampling */
  int smoothing_factor;         /* 1..100, or 0 for no input smoothing */
  J_DCT_METHOD dct_method;      /* DCT algorithm selector */

  /* The restart interval can be specified in absolute MCUs by setting
   * restart_interval, or in MCU rows by setting restart_in_rows
   * (in which case the correct restart_interval will be figured
   * for each scan).
   */
  unsigned int restart_interval; /* MCUs per restart, or 0 for no restart */
  int restart_in_rows;          /* if > 0, MCU rows per restart interval */

  /* Parameters controlling emission of special markers. */

  boolean write_JFIF_header;    /* should a JFIF marker be written? */
  UINT8 JFIF_major_version;     /* What to write for the JFIF version number */
  UINT8 JFIF_minor_version;
  /* These three values are not used by the JPEG code, merely copied */
  /* into the JFIF APP0 marker.  density_unit can be 0 for unknown, */
  /* 1 for dots/inch, or 2 for dots/cm.  Note that the pixel aspect */
  /* ratio is defined by X_density/Y_density even when density_unit=0. */
  UINT8 density_unit;           /* JFIF code for pixel size units */
  UINT16 X_density;             /* Horizontal pixel density */
  UINT16 Y_density;             /* Vertical pixel density */
  boolean write_Adobe_marker;   /* should an Adobe marker be written? */

  /* State variable: index of next scanline to be written to
   * jpeg_write_scanlines().  Application may use this to control its
   * processing loop, e.g., "while (next_scanline < image_height)".
   */

  JDIMENSION next_scanline;     /* 0 .. image_height-1  */

  /* Remaining fields are known throughout compressor, but generally
   * should not be touched by a surrounding application.
   */

  /*
   * These fields are computed during compression startup
   */
  boolean progressive_mode;     /* TRUE if scan script uses progressive mode */
  int max_h_samp_factor;        /* largest h_samp_factor */
  int max_v_samp_factor;        /* largest v_samp_factor */

  int min_DCT_h_scaled_size;    /* smallest DCT_h_scaled_size of any component */
  int min_DCT_v_scaled_size;    /* smallest DCT_v_scaled_size of any component */

  JDIMENSION total_iMCU_rows;   /* # of iMCU rows to be input to coef ctlr */
  /* The coefficient controller receives data in units of MCU rows as defined
   * for fully interleaved scans (whether the JPEG file is interleaved or not).
   * There are v_samp_factor * 8 sample rows of each component in an
   * "iMCU" (interleaved MCU) row.
   */

  /*
   * These fields are valid during any one scan.
   * They describe the components and MCUs actually appearing in the scan.
   */
  int comps_in_scan;            /* # of JPEG components in this scan */
  jpeg_component_info *cur_comp_info[4];
  /* *cur_comp_info[i] describes component that appears i'th in SOS */

  JDIMENSION MCUs_per_row;      /* # of MCUs across the image */
  JDIMENSION MCU_rows_in_scan;  /* # of MCU rows in the image */

  int blocks_in_MCU;            /* # of DCT blocks per MCU */
  int MCU_membership[10];
  /* MCU_membership[i] is index in cur_comp_info of component owning */
  /* i'th block in an MCU */

  int Ss, Se, Ah, Al;           /* progressive JPEG parameters for scan */

  int block_size;               /* the basic DCT block size: 1..16 */
  const int *natural_order;     /* natural-order position array */
  int lim_Se;                   /* min( Se, 82-1 ) */

  /*
   * Links to compression subobjects (methods and private variables of modules)
   */
  struct jpeg_comp_master *master;
  struct jpeg_c_main_controller *main;
  struct jpeg_c_prep_controller *prep;
  struct jpeg_c_coef_controller *coef;
  struct jpeg_marker_writer *marker;
  struct jpeg_color_converter *cconvert;
  struct jpeg_downsampler *downsample;
  struct jpeg_forward_dct *fdct;
  struct jpeg_entropy_encoder *entropy;
  jpeg_scan_info *script_space; /* workspace for jpeg_simple_progression */
  int script_space_size;
} jpeg_compress_struct;

typedef struct jpeg_decompress_struct {
  struct jpeg_error_mgr *err;
  struct jpeg_memory_mgr *mem;
  struct jpeg_progress_mgr *progress;
  void *client_data;
  boolean is_decompressor;
  int global_state;
  struct jpeg_source_mgr *src;
  JDIMENSION image_width;
  JDIMENSION image_height;
  int num_components;
  J_COLOR_SPACE jpeg_color_space;
  J_COLOR_SPACE out_color_space;
  unsigned int scale_num, scale_denom;
  double output_gamma;          /* image gamma wanted in output */
  boolean buffered_image;       /* TRUE=multiple output passes */
  boolean raw_data_out;         /* TRUE=downsampled data wanted */
  J_DCT_METHOD dct_method;      /* IDCT algorithm selector */
  boolean do_fancy_upsampling;  /* TRUE=apply fancy upsampling */
  boolean do_block_smoothing;   /* TRUE=apply interblock smoothing */
  boolean quantize_colors;      /* TRUE=colormapped output wanted */
  J_DITHER_MODE dither_mode;    /* type of color dithering to use */
  boolean two_pass_quantize;    /* TRUE=use two-pass color quantization */
  int desired_number_of_colors; /* max # colors to use in created colormap */
  boolean enable_1pass_quant;   /* enable future use of 1-pass quantizer */
  boolean enable_external_quant;/* enable future use of external colormap */
  boolean enable_2pass_quant;   /* enable future use of 2-pass quantizer */
  JDIMENSION output_width;      /* scaled image width */
  JDIMENSION output_height;     /* scaled image height */
  int out_color_components;     /* # of color components in out_color_space */
  int output_components;        /* # of color components returned */
  int rec_outbuf_height;        /* min recommended height of scanline buffer */
  int actual_number_of_colors;  /* number of entries in use */
  JSAMPARRAY colormap;          /* The color map as a 2-D pixel array */
  JDIMENSION output_scanline;   /* 0 .. output_height-1  */
  int input_scan_number;        /* Number of SOS markers seen so far */
  JDIMENSION input_iMCU_row;    /* Number of iMCU rows completed */
  int output_scan_number;       /* Nominal scan number being displayed */
  JDIMENSION output_iMCU_row;   /* Number of iMCU rows read */
  int (*coef_bits)[64];   /* -1 or current Al value for each coef */
  JQUANT_TBL *quant_tbl_ptrs[4];
  JHUFF_TBL *dc_huff_tbl_ptrs[4];
  JHUFF_TBL *ac_huff_tbl_ptrs[4];
  int data_precision;           /* bits of precision in image data */
  jpeg_component_info *comp_info;
  boolean is_baseline;          /* TRUE if Baseline SOF0 encountered */
  boolean progressive_mode;     /* TRUE if SOFn specifies progressive mode */
  boolean arith_code;           /* TRUE=arithmetic coding, FALSE=Huffman */
  UINT8 arith_dc_L[16]; /* L values for DC arith-coding tables */
  UINT8 arith_dc_U[16]; /* U values for DC arith-coding tables */
  UINT8 arith_ac_K[16]; /* Kx values for AC arith-coding tables */
  unsigned int restart_interval; /* MCUs per restart interval, or 0 for no restart */
  boolean saw_JFIF_marker;      /* TRUE iff a JFIF APP0 marker was found */
  UINT8 JFIF_major_version;     /* JFIF version number */
  UINT8 JFIF_minor_version;
  UINT8 density_unit;           /* JFIF code for pixel size units */
  UINT16 X_density;             /* Horizontal pixel density */
  UINT16 Y_density;             /* Vertical pixel density */
  boolean saw_Adobe_marker;     /* TRUE iff an Adobe APP14 marker was found */
  UINT8 Adobe_transform;        /* Color transform code from Adobe marker */
  boolean CCIR601_sampling;     /* TRUE=first samples are cosited */
  jpeg_saved_marker_ptr marker_list; /* Head of list of saved markers */
  int max_h_samp_factor;        /* largest h_samp_factor */
  int max_v_samp_factor;        /* largest v_samp_factor */
  int min_DCT_h_scaled_size;    /* smallest DCT_h_scaled_size of any component */
  int min_DCT_v_scaled_size;    /* smallest DCT_v_scaled_size of any component */
  JDIMENSION total_iMCU_rows;   /* # of iMCU rows in image */
  JSAMPLE *sample_range_limit;  /* table for fast range-limiting */
  int comps_in_scan;            /* # of JPEG components in this scan */
  jpeg_component_info *cur_comp_info[4];
  JDIMENSION MCUs_per_row;      /* # of MCUs across the image */
  JDIMENSION MCU_rows_in_scan;  /* # of MCU rows in the image */
  int blocks_in_MCU;            /* # of DCT blocks per MCU */
  int MCU_membership[10];
  int Ss, Se, Ah, Al;           /* progressive JPEG parameters for scan */
  int block_size;               /* the basic DCT block size: 1..16 */
  const int *natural_order; /* natural-order position array for entropy decode */
  int lim_Se;                   /* min( Se, 64-1 ) for entropy decode */
  int unread_marker;
  struct jpeg_decomp_master *master;
  struct jpeg_d_main_controller *main;
  struct jpeg_d_coef_controller *coef;
  struct jpeg_d_post_controller *post;
  struct jpeg_input_controller *inputctl;
  struct jpeg_marker_reader *marker;
  struct jpeg_entropy_decoder *entropy;
  struct jpeg_inverse_dct *idct;
  struct jpeg_upsampler *upsample;
  struct jpeg_color_deconverter *cconvert;
  struct jpeg_color_quantizer *cquantize;
} jpeg_decompress_struct;

typedef void (*jpeg_error_exit_callback) (j_common_ptr cinfo);
typedef void (*jpeg_emit_message_callback) (j_common_ptr cinfo, int msg_level);
typedef void (*jpeg_output_message_callback) (j_common_ptr cinfo);
typedef void (*jpeg_format_message_callback) (j_common_ptr cinfo, char * buffer);

typedef struct jpeg_error_mgr {
	jpeg_error_exit_callback error_exit;
	jpeg_emit_message_callback emit_message;
	jpeg_output_message_callback output_message;
	jpeg_format_message_callback format_message;
	void (*reset_error_mgr) (j_common_ptr cinfo);
	int msg_code;
	union {
		int i[8];
		char s[80];
	} msg_parm;
	int trace_level;
	long num_warnings;
	const char * const * jpeg_message_table;
	int last_jpeg_message;
	const char * const * addon_message_table;
	int first_addon_message;
	int last_addon_message;
} jpeg_error_mgr;

struct jpeg_progress_mgr {
	void (*progress_monitor) (j_common_ptr cinfo);
	long pass_counter;
	long pass_limit;
	int completed_passes;
	int total_passes;
};

typedef void    (*jpeg_init_destination_callback)    (j_compress_ptr cinfo);
typedef boolean (*jpeg_empty_output_buffer_callback) (j_compress_ptr cinfo);
typedef void    (*jpeg_term_destination_callback)    (j_compress_ptr cinfo);

typedef struct jpeg_destination_mgr {
	JOCTET * next_output_byte;
	size_t free_in_buffer;
	jpeg_init_destination_callback     init_destination;
	jpeg_empty_output_buffer_callback  empty_output_buffer;
	jpeg_term_destination_callback     term_destination;
} jpeg_destination_mgr;

typedef void    (*jpeg_init_source_callback)       (j_decompress_ptr cinfo);
typedef boolean (*jpeg_fill_input_buffer_callback) (j_decompress_ptr cinfo);
typedef void    (*jpeg_skip_input_data_callback)   (j_decompress_ptr cinfo, long num_bytes);
typedef boolean (*jpeg_resync_to_restart_callback) (j_decompress_ptr cinfo, int desired);
typedef void    (*jpeg_term_source_callback)       (j_decompress_ptr cinfo);

typedef struct jpeg_source_mgr {
	const JOCTET * next_input_byte;
	size_t bytes_in_buffer;
	jpeg_init_source_callback        init_source;
	jpeg_fill_input_buffer_callback  fill_input_buffer;
	jpeg_skip_input_data_callback    skip_input_data;
	jpeg_resync_to_restart_callback  resync_to_restart;
	jpeg_term_source_callback        term_source;
} jpeg_source_mgr;

typedef struct jvirt_sarray_control * jvirt_sarray_ptr;
typedef struct jvirt_barray_control * jvirt_barray_ptr;

struct jpeg_memory_mgr {
  void * (*alloc_small) (j_common_ptr cinfo, int pool_id, size_t sizeofobject);
  void * (*alloc_large) (j_common_ptr cinfo, int pool_id, size_t sizeofobject);
  JSAMPARRAY (*alloc_sarray) (j_common_ptr cinfo, int pool_id, JDIMENSION samplesperrow, JDIMENSION numrows);
  JBLOCKARRAY (*alloc_barray) (j_common_ptr cinfo, int pool_id, JDIMENSION blocksperrow, JDIMENSION numrows);
  jvirt_sarray_ptr (*request_virt_sarray) (j_common_ptr cinfo, int pool_id, boolean pre_zero, JDIMENSION samplesperrow, JDIMENSION numrows, JDIMENSION maxaccess);
  jvirt_barray_ptr (*request_virt_barray) (j_common_ptr cinfo, int pool_id, boolean pre_zero, JDIMENSION blocksperrow, JDIMENSION numrows, JDIMENSION maxaccess);
  void (*realize_virt_arrays) (j_common_ptr cinfo);
  JSAMPARRAY (*access_virt_sarray) (j_common_ptr cinfo, jvirt_sarray_ptr ptr, JDIMENSION start_row, JDIMENSION num_rows, boolean writable);
  JBLOCKARRAY (*access_virt_barray) (j_common_ptr cinfo, jvirt_barray_ptr ptr, JDIMENSION start_row, JDIMENSION num_rows, boolean writable);
  void (*free_pool) (j_common_ptr cinfo, int pool_id);
  void (*self_destruct) (j_common_ptr cinfo);
  long max_memory_to_use;
  long max_alloc_chunk;
};
void jpeg_mem_dest (j_compress_ptr cinfo, unsigned char **outbuffer,
                            unsigned long *outsize);
void jpeg_mem_src (j_decompress_ptr cinfo,
                          const unsigned char *inbuffer, unsigned long insize);
typedef boolean (*jpeg_marker_parser_method) (j_decompress_ptr cinfo);

struct jpeg_error_mgr * jpeg_std_error (struct jpeg_error_mgr *err);

void jpeg_CreateCompress (j_compress_ptr cinfo, int version, size_t structsize);
void jpeg_CreateDecompress (j_decompress_ptr cinfo, int version, size_t structsize);
void jpeg_destroy_compress (j_compress_ptr cinfo);
void jpeg_destroy_decompress (j_decompress_ptr cinfo);
void jpeg_stdio_dest (j_compress_ptr cinfo, FILE * outfile);
void jpeg_stdio_src (j_decompress_ptr cinfo, FILE * infile);
void jpeg_set_defaults (j_compress_ptr cinfo);
void jpeg_set_colorspace (j_compress_ptr cinfo, J_COLOR_SPACE colorspace);
void jpeg_default_colorspace (j_compress_ptr cinfo);
void jpeg_set_quality (j_compress_ptr cinfo, int quality, boolean force_baseline);
void jpeg_set_linear_quality (j_compress_ptr cinfo, int scale_factor, boolean force_baseline);
void jpeg_add_quant_table (j_compress_ptr cinfo, int which_tbl, const unsigned int *basic_table, int scale_factor, boolean force_baseline);
int jpeg_quality_scaling (int quality);
void jpeg_simple_progression (j_compress_ptr cinfo);
void jpeg_suppress_tables (j_compress_ptr cinfo, boolean suppress);
JQUANT_TBL * jpeg_alloc_quant_table (j_common_ptr cinfo);
JHUFF_TBL * jpeg_alloc_huff_table (j_common_ptr cinfo);
void jpeg_start_compress (j_compress_ptr cinfo, boolean write_all_tables);
JDIMENSION jpeg_write_scanlines (j_compress_ptr cinfo, JSAMPARRAY scanlines, JDIMENSION num_lines);
void jpeg_finish_compress (j_compress_ptr cinfo);
JDIMENSION jpeg_write_raw_data (j_compress_ptr cinfo, JSAMPIMAGE data, JDIMENSION num_lines);
void jpeg_write_marker (j_compress_ptr cinfo, int marker, const JOCTET * dataptr, unsigned int datalen);
void jpeg_write_m_header (j_compress_ptr cinfo, int marker, unsigned int datalen);
void jpeg_write_m_byte (j_compress_ptr cinfo, int val);
void jpeg_write_tables (j_compress_ptr cinfo);
int jpeg_read_header (j_decompress_ptr cinfo, boolean require_image);
boolean jpeg_start_decompress (j_decompress_ptr cinfo);
JDIMENSION jpeg_read_scanlines (j_decompress_ptr cinfo, JSAMPARRAY scanlines, JDIMENSION max_lines);
boolean jpeg_finish_decompress (j_decompress_ptr cinfo);
JDIMENSION jpeg_read_raw_data (j_decompress_ptr cinfo, JSAMPIMAGE data, JDIMENSION max_lines);
boolean jpeg_has_multiple_scans (j_decompress_ptr cinfo);
boolean jpeg_start_output (j_decompress_ptr cinfo, int scan_number);
boolean jpeg_finish_output (j_decompress_ptr cinfo);
boolean jpeg_input_complete (j_decompress_ptr cinfo);
void jpeg_new_colormap (j_decompress_ptr cinfo);
int jpeg_consume_input (j_decompress_ptr cinfo);
void jpeg_calc_output_dimensions (j_decompress_ptr cinfo);
void jpeg_save_markers (j_decompress_ptr cinfo, int marker_code, unsigned int length_limit);
void jpeg_set_marker_processor (j_decompress_ptr cinfo, int marker_code, jpeg_marker_parser_method routine);
jvirt_barray_ptr * jpeg_read_coefficients (j_decompress_ptr cinfo);
void jpeg_write_coefficients (j_compress_ptr cinfo, jvirt_barray_ptr * coef_arrays);
void jpeg_copy_critical_parameters (j_decompress_ptr srcinfo, j_compress_ptr dstinfo);
void jpeg_abort_compress (j_compress_ptr cinfo);
void jpeg_abort_decompress (j_decompress_ptr cinfo);
void jpeg_abort (j_common_ptr cinfo);
void jpeg_destroy (j_common_ptr cinfo);
boolean jpeg_resync_to_restart (j_decompress_ptr cinfo, int desired);
void *memmove(void *dest, const void *src, size_t n);
struct cjpeg_source_struct {
  void (*start_input) (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);
  JDIMENSION (*get_pixel_rows) (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);
  void (*finish_input) (j_compress_ptr cinfo, cjpeg_source_ptr sinfo);

  FILE *input_file;

  JSAMPARRAY buffer;
  JDIMENSION buffer_height;

  JSAMPARRAY plane_pointer[4];

  jpeg_saved_marker_ptr marker_list;
};
cjpeg_source_ptr jinit_read_jpeg (j_compress_ptr cinfo);
cjpeg_source_ptr jinit_read_png (j_compress_ptr cinfo);
typedef struct {
  struct jpeg_destination_mgr pub; /* public fields */

  unsigned char ** outbuffer;	/* target buffer */
  unsigned long * outsize;
  unsigned char * newbuffer;	/* newly allocated buffer */
  JOCTET * buffer;		/* start of buffer */
  size_t bufsize;
} my_mem_destination_mgr;
typedef my_mem_destination_mgr * my_mem_dest_ptr;
]]

local C = ffi.load('libjpeg.so')

return C


