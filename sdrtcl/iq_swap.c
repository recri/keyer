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

#include "../dspmath/dspmath.h"
#include "framework.h"

/*
** swap i/q.
** You can do this by simply reversing the audio wiring in jack, too.
*/
typedef struct {
  framework_t fw;
  int swap;
} _t;

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  if (data->swap) {
    for (int i = nframes; --i >= 0; ) {
      *out0++ = *in1++;
      *out1++ = *in0++;
    }
  } else {
    for (int i = nframes; --i >= 0; ) {
      *out0++ = *in0++;
      *out1++ = *in1++;
    }
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-swap", "swap", "Swap", "0", fw_option_int, fw_flag_none, offsetof(_t,swap), "swap i and q or leave them alone" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  NULL,				// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs
  "a component which swaps the I/Q channels"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_swap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::iq-swap", "1.0.0", "sdrtcl::iq-swap", _factory);
}
