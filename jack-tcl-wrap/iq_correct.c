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

#include "../sdrkit/iq_correct.h"
#include "framework.h"

typedef iq_correct_options_t options_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  iq_correct_t iqb;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e = iq_correct_init(&data->iqb, &data->opts); if (e != &data->iqb) return e;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  iq_correct_preprocess(&data->iqb, nframes);
  for (int i = nframes; --i >= 0; ) {
    float _Complex y = iq_correct_process(&data->iqb, *in0++ + *in1++ * I);
    *out0++ = creal(y);
    *out1++ = cimag(y);
  }
  iq_correct_postprocess(&data->iqb, nframes);
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_Obj *result[] = {
    Tcl_NewDoubleObj(crealf(data->iqb.w)), Tcl_NewDoubleObj(cimagf(data->iqb.w)),
    Tcl_NewDoubleObj(data->iqb.avg_net_dw2), Tcl_NewDoubleObj(data->iqb.avg_mag2_dw),
    NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(4, result));
  return TCL_OK;
}
static int _reset(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s reset", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  data->iqb.w = 0.0f;
  data->iqb.avg_net_dw2 = 0.0f;
  data->iqb.avg_mag2_dw = 0.0f;
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = save.mu != data->opts.mu;
  if (data->modified) {
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
  { "get",   _get,   "fetch the current adaptive filter coefficients" },
  { "reset", _reset, "reset the current adaptive filter coefficients to zero" },
  { NULL }
};

// the template which describes this command
static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
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
  return framework_init(interp, "sdrkit::iq-correct", "1.0.0", "sdrkit::iq-correct", _factory);
}
