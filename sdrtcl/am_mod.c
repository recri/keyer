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

#define FRAMEWORK_USES_JACK 1

#include "../dspmath/mod_am.h"
#include "framework.h"

/*
** modulate AM.
*/
typedef struct {
  framework_t fw;
  mod_am_t am;
  mod_am_options_t opts;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e = mod_am_init(&data->am, &data->opts); if (e != &data->am) return e;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    complex float z = mod_am_process(&data->am, (*in0++ + *in1++)/2.0f);
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float carrier_level = data->opts.carrier_level;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  if (carrier_level != data->opts.carrier_level) {
    void *e = mod_am_preconfigure(&data->am, &data->opts); if (e != &data->am) {
      Tcl_SetResult(interp, e, TCL_STATIC);
      data->opts.carrier_level = carrier_level;
      return TCL_ERROR;
    }
    mod_am_configure(&data->am, &data->opts);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-level", "level", "Level", "0.5", fw_option_float, 0, offsetof(_t, opts.carrier_level), "carrier level" },
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
  "an AM modulation component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Am_mod_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::am-mod", "1.0.0", "sdrtcl::am-mod", _factory);
}

