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
** create an IQ corrector module which adaptively adjusts the phase and
** relative magnitudes of the I and Q channels to balance.
*/
#define FRAMEWORK_USES_JACK 1

#include <fftw3.h>
#include "../dspmath/iq_correct.h"
#include "framework.h"

typedef iq_correct_options_t options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  iq_correct_t iqb;
  float complex *buffer;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e = iq_correct_init(&data->iqb, &data->opts); if (e != &data->iqb) return e;
  data->buffer = fftwf_malloc(sdrkit_buffer_size(arg)*sizeof(float complex));
  if (data->buffer == NULL) return "allocation failure";
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->buffer != NULL) { fftwf_free(data->buffer); data->buffer = NULL; }
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    const float complex z = *in0++ + *in1++ * I;
    const float _Complex y = iq_correct_process(&data->iqb, z);
    *out0++ = crealf(y);
    *out1++ = cimagf(y);
    data->buffer[i] = z;
  }
  return 0;
}

// estimate magnitude of error signal
static int _error(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s error", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  double complex sum_z1_squared = 0;
  int n = sdrkit_buffer_size(data);
  for (int i = 0; i < n; i += 1)
    sum_z1_squared += data->buffer[i] * data->buffer[i];
  double complex avg_z1_squared = sum_z1_squared / n;
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)), Tcl_NewDoubleObj(creal(avg_z1_squared)), Tcl_NewDoubleObj(cimag(avg_z1_squared)), NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(3, result));
  return TCL_OK;
}
// train a round given w and mu over the current sample buffer
static int _train(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 5)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s train mu wreal wimag", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  double mu, wreal, wimag;
  if (Tcl_GetDoubleFromObj(interp, objv[2], &mu) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[3], &wreal) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[4], &wimag) != TCL_OK) return TCL_ERROR;
  double complex w = wreal + I * wimag;
  int n = sdrkit_buffer_size(data);
  for (int i = 0; i < n; i += 1) {
    const double complex z1 = data->buffer[i] + w * conjf(data->buffer[i]);	// compute corrected sample
    w -= mu * z1 * z1;		// update filter coefficients += -mu * error
  }
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)), Tcl_NewDoubleObj(creal(w)), Tcl_NewDoubleObj(cimag(w)), NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(3, result));
  return TCL_OK;
}
// get the current mu and w
static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)), Tcl_NewDoubleObj(data->iqb.mu), Tcl_NewDoubleObj(crealf(data->iqb.w)), Tcl_NewDoubleObj(cimagf(data->iqb.w)), NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(4, result));
  return TCL_OK;
}
// set the current mu and w
static int _set(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 5)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s set mu wreal wimag", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  double mu, wreal, wimag;
  if (Tcl_GetDoubleFromObj(interp, objv[2], &mu) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[3], &wreal) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[4], &wimag) != TCL_OK) return TCL_ERROR;
  data->iqb.w = wreal + I * wimag;
  data->iqb.mu = mu;
  return TCL_OK;
}
// command dispatcher
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  if (save.mu != data->opts.mu) {
    void *e = iq_correct_preconfigure(&data->iqb, &data->opts);
    if (e != &data->iqb) {
      data->opts = save;
      return fw_error_str(interp, e);
    }
    iq_correct_configure(&data->iqb, &data->opts);
  }
  return TCL_OK;
}

// the options that the command implements
static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-mu", "mu", "Mu", "0.25", fw_option_float, 0, offsetof(_t, opts.mu),	    "adaptation factor, larger is faster" },
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "error", _error, "estimate error signal to adaptive filter" },
  { "train", _train, "train adaptive filter over current sample buffer" },
  { "get", _get, "fetch the current adaptive filter coefficients" },
  { "set", _set, "set the current adaptive filter coefficients" },
  { NULL }
};

// the template which describes this command
static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component to adjust the I/Q channel balance"
};

// the factory command which creates iq balance commands
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_correct_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::iq-correct", "1.0.0", "sdrtcl::iq-correct", _factory);
}
