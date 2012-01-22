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

#include "framework.h"

#include <math.h>
#include <complex.h>

#include "../sdrkit/dmath.h"

/*
** create a gain module which scales its inputs by a scalar
** and stores them into the outputs.
** a contraction of a real constant and mixer.
** one scalar parameter.
*/
typedef struct {
  framework_t fw;
  float _Complex gain;
  float dBgain;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  // data->dBgain = -30.0f;
  data->gain = powf(10.0f, data->dBgain / 20.0f);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  const _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    float _Complex z = data-> gain * (*in0++ + I * *in1++);
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float dBgain = data->dBgain;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (data->dBgain != dBgain) data->gain = powf(10.0f, dBgain / 20.0f);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-gain",   "gain",   "Gain",   "-100.0",   fw_option_float, 0,	offsetof(_t, dBgain),	      "gain in dB" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a gain component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Gain_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::gain", "1.0.0", "sdrkit::gain", _factory);
}

