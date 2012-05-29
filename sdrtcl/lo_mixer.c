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
** a local oscillator-mixer combination
*/

#define FRAMEWORK_USES_JACK 1

#include "framework.h"
#include "../dspmath/lo_mixer.h"

typedef struct {
  framework_t fw;
  lo_mixer_t lo;
  int modified;
  float hertz;
  float gain;
} _t;

static void _setup(_t *data, float hertz) {
  if (hertz != data->hertz) {
    data->hertz = hertz;
    data->modified = data->fw.busy = 1;
  }
}
  
static void _update(_t *data) {
  if (data->modified) {
    data->modified = data->fw.busy = 0;
    lo_mixer_update(&data->lo, data->hertz, sdrkit_sample_rate(data));
  }
}

static void *_init(void *arg) {
  _t * const data = (_t *)arg;
  data->modified = data->fw.busy = 0;
  // data->hertz = 700.0f;
  lo_mixer_init(&data->lo, data->hertz, sdrkit_sample_rate(data));
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  _update(data);
  for (int i = nframes; --i >= 0; ) {
    float complex out = lo_mixer_process(&data->lo, *in0++ + I * *in1++);
    *out0++ = crealf(out);
    *out1++ = cimagf(out);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float hertz = data->hertz;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (data->hertz != hertz) {
    /* if (fabsf(data->hertz) > sdrkit_sample_rate(data)/4) {
      data->hertz = hertz;
      return fw_error_str(interp, "frequency is more than samplerate/4");
      } */
    data->modified = data->fw.busy = 1;
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-freq",   "frequency","Hertz","700.0",    fw_option_float, 0,	offsetof(_t, hertz),	      "frequency of oscillator in Hertz" },
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
  "a component which combines an oscillator and a mixer to convert a basebane I/Q signal to a new IF"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Lo_mixer_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::lo-mixer", "1.0.0", "sdrtcl::lo-mixer", _factory);
}
