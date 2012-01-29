/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/

/*
*/
#define FRAMEWORK_USES_JACK 0

#include "../sdrkit/filter_FIR.h"
#include "framework.h"

#if FILTER_BAND_PASS || FILTER_BAND_STOP || FILTER_HILBERT

#define FILTER_OPT_VARS	float lo, hi
#define FILTER_OPT_DEFS \
  { "-lo", "lo", "Hertz", "400.0",         fw_option_float, fw_flag_none, offsetof(_t, opts.lo),     "low frequency filter cutoff" },\
  { "-hi", "hi", "Hertz", "1200.0",        fw_option_float, fw_flag_none, offsetof(_t, opts.hi),     "high frequency filter cutoff" }
#define FILTER_OPT_TEST(data,save) data->opts.lo != save.lo || data->opts.hi != save.hi  

#elif FILTER_LOW_PASS || FILTER_HIGH_PASS

#define FILTER_OPT_VARS	float cutoff
#define FILTER_OPT_DEFS \
  { "-cutoff", "cutoff", "Hertz", "800.0", fw_option_float, fw_flag_none, offsetof(_t, opts.cutoff), "filter cutoff" }
#define FILTER_OPT_TEST(data,save) data->opts.cutoff != save.cutoff

#else  // not any of band pass, band stop, hilbert, low pass, or high pass

#error "unknown FIR filter type"

#endif

#if FILTER_COMPLEX
#define FILTER_BYTE_SIZE(size) ((size)*2*sizeof(float))
#define FILTER_DECL float complex *

#if FILTER_BAND_PASS
#define FILTER_CALL(data,filter,window)	bandpass_complex(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window)
#define FILTER_TYPE_STRING "complex band pass"
#define FILTER_INIT_NAME Filter_fir_band_pass_complex_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-band-pass-complex"
#elif FILTER_BAND_STOP
#define FILTER_CALL(data,filter,window) bandstop_complex(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window)
#define FILTER_TYPE_STRING "complex band stop"
#define FILTER_INIT_NAME Filter_fir_band_stop_complex_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-band-stop-complex"
#elif FILTER_HIGH_PASS
#define FILTER_CALL(data,filter,window) highpass_complex(data->opts.cutoff, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "complex high pass"
#define FILTER_INIT_NAME Filter_fir_high_pass_complex_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-high-pass-complex"
#elif FILTER_HILBERT
#define FILTER_CALL(data,filter,window) hilbert_complex(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "complex hilbert"
#define FILTER_INIT_NAME Filter_fir_hilbert_complex_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-hilbert-complex"
#elif FILTER_LOW_PASS
#define FILTER_CALL(data,filter,window) lowpass_complex(data->opts.cutoff, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "complex low pass"
#define FILTER_INIT_NAME Filter_fir_low_pass_complex_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-low-pass-complex"
#endif

#elif FILTER_REAL
#define FILTER_DECL float *
#define FILTER_BYTE_SIZE(size) ((size)*sizeof(float))
#define FILTER_SAMPLE_TYPE_STRING "real"

#if FILTER_BAND_PASS
#define FILTER_CALL(data,filter,window)	bandpass_real(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window)
#define FILTER_TYPE_STRING "real band pass"
#define FILTER_INIT_NAME Filter_fir_band_pass_real_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-band-pass-real"
#elif FILTER_BAND_STOP
#define FILTER_CALL(data,filter,window) bandstop_real(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window)
#define FILTER_TYPE_STRING "real band stop"
#define FILTER_INIT_NAME Filter_fir_band_stop_real_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-band-stop-real"
#elif FILTER_HIGH_PASS
#define FILTER_CALL(data,filter,window) highpass_real(data->opts.cutoff, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "real high pass"
#define FILTER_INIT_NAME Filter_fir_high_pass_real_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-high-pass-real"
#elif FILTER_HILBERT
#define FILTER_CALL(data,filter,window) hilbert_real(data->opts.lo, data->opts.hi, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "real hilbert"
#define FILTER_INIT_NAME Filter_fir_hilbert_real_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-hilbert-real"
#elif FILTER_LOW_PASS
#define FILTER_CALL(data,filter,window) lowpass_real(data->opts.cutoff, data->opts.sample_rate, data->opts.size, filter, window);
#define FILTER_TYPE_STRING "real low pass"
#define FILTER_INIT_NAME Filter_fir_low_pass_real_Init
#define FILTER_TCL_STRING "sdrkit::filter-FIR-low-pass-real"
#endif

#else
#error "unknown filter sample type"
#endif

/*
** create a FIR filter module
*/
typedef struct {
  int size;			/* size of window in floats */
  int sample_rate;
  Tcl_Obj *window;
  FILTER_OPT_VARS;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  Tcl_Obj *filter;		/* window as byte array */
} _t;

static void *_configure(_t *data) {
  if (data->opts.window == NULL) return (void *)"no window function specified for filter";
  int window_size;
  float *window = (float *)Tcl_GetByteArrayFromObj(data->opts.window, &window_size);
  if (window_size/sizeof(float) != data->opts.size) return (void *)"window function is not the same size as the filter";
  if (data->filter != NULL) Tcl_DecrRefCount(data->filter);
  data->filter = Tcl_NewObj();
  Tcl_IncrRefCount(data->filter);
  FILTER_DECL filter = (FILTER_DECL)Tcl_SetByteArrayLength(data->opts.window, FILTER_BYTE_SIZE(data->opts.size));
  FILTER_CALL(data, filter, window);
  return data;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void * e = _configure(data); if (e != data) return e;
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->filter != NULL) Tcl_DecrRefCount(data->filter);
  data->filter = NULL;
  if (data->opts.window != NULL) Tcl_DecrRefCount(data->opts.window);
  data->opts.window = NULL;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, data->filter);
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  if (data->opts.size != save.size ||
      data->opts.window != save.window ||
      FILTER_OPT_TEST(data,save)) {
    void *e = _configure(data); if (e != data) {
      data->opts = save;
      Tcl_SetResult(interp, e, TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
  /* no -server or -client, not a jack client */
  { "-verbose", "verbose", "Verbose", "0", fw_option_int,   fw_flag_none, offsetof(_t, fw.verbose), "amount of diagnostic output" },
  { "-size", "size", "Size", "1024",	   fw_option_int,   fw_flag_none, offsetof(_t, opts.size),  "window size" },
  FILTER_OPT_DEFS,
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",   _get,   "get the byte array that implements the window" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  NULL,				// process callback
  0, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a " FILTER_TYPE_STRING " FIR filter component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT FILTER_INIT_NAME(Tcl_Interp *interp) {
  return framework_init(interp, FILTER_TCL_STRING, "1.0.0", FILTER_TCL_STRING, _factory);
}

