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

#include "../sdrkit/dmath.h"
#include "framework.h"
#include <fftw3.h>

/*
** create a complex 1d fft
** size of fft as parameter to factory
*/
typedef struct {
  int size;
  int planbits;
  int direction;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  fftwf_complex *inout;		/* input/output array */
  fftwf_plan plan;		/* fftw plan */
} _t;

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data != NULL) {
    if (data->plan != NULL) fftwf_destroy_plan(data->plan);
    if (data->inout != NULL) fftwf_free(data->inout);
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  if (data->opts.size <= 16) return (void *)"size is too small";
  if (data->opts.direction != FFTW_FORWARD && data->opts.direction != FFTW_BACKWARD)
    return (void *)"direction must be -1 (forward) or +1 (backward)";
  if ((data->inout = (fftwf_complex *)fftwf_malloc(data->opts.size*sizeof(fftwf_complex))) &&
      (data->plan = fftwf_plan_dft_1d(data->opts.size,  data->inout, data->inout, data->opts.direction, data->opts.planbits))) {
    return data;
  }
  _delete(data);
  return "allocation failure";
}

/*
** The command executes a complex fft given an input byte array
** of interleaved i/q of the correct size, and a window which is
** an integral multiple of the fft size.
**
** The result is returned as a byte array of complex coefficients
** in the fftw standard order.
**
** The result is stored into a new byte array.
*/
static int _exec(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int ninput;
  float _Complex *input;
  // check the argument count
  if (argc < 3 || argc > 4) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s exec input_byte_array [window_byte_array]", Tcl_GetString(objv[0])));
  // check the input byte array
  if ((input = (float _Complex *)Tcl_GetByteArrayFromObj(objv[2], &ninput)) == NULL) return fw_error_str(interp, "failed to get input byte array");
  // convert bytes to number of input samples
  ninput /= sizeof(float complex);
  // check for a window
  int nwindow;
  float *window;
  if (argc == 4) {
    if ((window = (float *)Tcl_GetByteArrayFromObj(objv[3], &nwindow)) == NULL)
      return fw_error_str(interp, "failed to get window byte array");
    // convert bytes to size of window
    nwindow /= sizeof(float);
    // check that window size makes sense
    if (nwindow < data->opts.size)
      return fw_error_str(interp, "window is not large enough for fft");
    if ((nwindow % data->opts.size) != 0)
      return fw_error_str(interp, "window is not an integral multiple of fft size");
    // check that input size is agreeable
    if (ninput < nwindow)
      return fw_error_str(interp, "not enough input samples for fft window");
    int polyphase = nwindow / data->opts.size;
    // make windowed input
    for (int i = 0; i < data->opts.size; i += 1) {
      data->inout[i] = *window++ * *input++;
    }
    // implement polyphase window
    for (int j = 1; j < polyphase; j += 1) {
      for (int i = 0; i < data->opts.size; i += 1) {
	data->inout[i] += *window++ * *input++;
      }
    }
  } else {
    // check that input size is agreeable
    if (ninput < data->opts.size)
      return fw_error_str(interp, "not enough input samples for fft window");
    // make square windowed input
    memcpy(data->inout, input, data->opts.size*sizeof(float complex));
  }
  // compute the fft
  fftwf_execute(data->plan);
  // create the result
  Tcl_Obj *result = Tcl_NewByteArrayObj((unsigned char *)data->inout, data->opts.size*sizeof(float complex));
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
      save.direction != data->opts.direction) {
    _delete(data);
    void *p = _init(data); if (p != data) return fw_error_str(interp, p);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-size",     "size",     "Samples",   "4096", fw_option_int, 0,	offsetof(_t, opts.size),        "size of fft computed" },
  { "-planbits", "planbits", "Planbits",  "0",	  fw_option_int, 0,	offsetof(_t, opts.planbits),    "fftw plan bits" },
  { "-direction","direction","Direction", "-1",	  fw_option_int, 0,     offsetof(_t, opts.direction),	"fft direction, 1=inverse or -1=forward" },
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
