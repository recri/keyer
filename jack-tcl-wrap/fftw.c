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

#include <complex.h>
#define __USE_XOPEN
#include <math.h>
#include <fftw3.h>

#include "framework.h"
#include "../sdrkit/window.h"

/*
** create a complex 1d fft
** size of fft as parameter to factory
*/
typedef struct {
  int size;
  int planbits;
  int window_type;		// should be a Tcl_Obj *
  int direction;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  fftwf_complex *inout;		/* input/output array */
  fftwf_plan plan;		/* fftw plan */
  float *window;		/* window */
} _t;

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data != NULL) {
    if (data->plan != NULL) fftwf_destroy_plan(data->plan);
    if (data->inout != NULL) fftwf_free(data->inout);
    if (data->window != NULL) fftwf_free(data->window);
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  if (data->opts.size <= 16) return (void *)"size is too small";
  if (data->opts.direction != FFTW_FORWARD && data->opts.direction != FFTW_BACKWARD)
    return (void *)"direction must be -1 (forward) or +1 (backward)";
  if (data->opts.window_type < WINDOW_RECTANGULAR || data->opts.window_type > WINDOW_NUTTALL)
    return (void *)"window_type is invalid";
  if ((data->inout = (fftwf_complex *)fftwf_malloc(data->opts.size*sizeof(fftwf_complex))) &&
      (data->window = (float *)fftwf_malloc(data->opts.size*sizeof(float))) &&
      (data->plan = fftwf_plan_dft_1d(data->opts.size,  data->inout, data->inout, data->opts.direction, data->opts.planbits))) {
    window_make(data->opts.window_type, data->opts.size, data->window);
    return data;
  }
  _delete(data);
  return "allocation failure";
}

/*
** The command executes a complex fft given an input byte array
** of interleaved i/q of the correct size.
**
** The result is returned as a byte array of complex coefficients
** in the fftw standard order.
**
** The result is stored into a new byte array or into the optional
** second output byte array argument, which may be the same as the
** input byte array.
*/
static int _exec(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  float _Complex *input;
  Tcl_Obj *output = NULL;
  // check the argument count
  if (argc < 3 || argc > 4) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s exec input_byte_array [ output_byte_array ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  // check the input byte array
  if ((input = (float _Complex *)Tcl_GetByteArrayFromObj(objv[2], &n)) == NULL || n < data->opts.size*2*sizeof(float)) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("byte_array argument does have not %d samples", data->opts.size));
    return TCL_ERROR;
  }
  // copy the input into the input buffer, applying the window
  for (int i = 0; i < data->opts.size; i += 1) {
    data->inout[i] = data->window[i] * *input++;
  }
  // compute the fft
  fftwf_execute(data->plan);
  // create the result
  Tcl_Obj *result;
  if (argc == 3) {
    result = Tcl_NewByteArrayObj((unsigned char *)data->inout, data->opts.size*2*sizeof(float));
  } else {
    Tcl_SetByteArrayObj(result = objv[3], (unsigned char *)data->inout, data->opts.size*2*sizeof(float));
  }
  // set the result
  Tcl_SetObjResult(interp,result);
  // return success
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  if (save.size != data->opts.size ||
      save.planbits != data->opts.planbits ||
      save.direction != data->opts.direction ||
      save.window_type != data->opts.window_type) {
    _delete(data);
    void *p = _init(data); if (p != data) {
      Tcl_SetResult(interp, (char *)p, TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-size",     "size",     "Samples",   "4096", fw_option_int, 0,	offsetof(_t, opts.size),        "size of fft computed" },
  { "-planbits", "planbits", "Planbits",  "0",	  fw_option_int, 0,	offsetof(_t, opts.planbits),    "fftw plan bits" },
  { "-window",   "window",   "Window",    "11",   fw_option_int, 0,	offsetof(_t, opts.window_type), "window used in fft, integer from sdrkit/window.h" },
  { "-direction","direction","Direction", "-1",	  fw_option_int, 0,     offsetof(_t, opts.direction),	"fft direction, 1 or -1" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "exec",	 _exec, "execute the fft on the supplied data" },
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
  "an fftw3 fast fourier transform component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Fftw_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::fftw", "1.0.0", "sdrkit::fftw", _factory);
}
