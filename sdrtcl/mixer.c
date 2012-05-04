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

#include "framework.h"
#include "../dspmath/dspmath.h"

/*
** create a mixer module which combines its inputs into an output
** no parameters.
** if one channel produces a real constant, then this is simply
** a gain block that scales by the real constant.
** if one channel produces a complex constant, then this scales
** and rotates.
*/
typedef struct {
  framework_t fw;
} _t;

static void *_init(void *arg) {
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *in2 = jack_port_get_buffer(framework_input(data,2), nframes);
  float *in3 = jack_port_get_buffer(framework_input(data,3), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    const _Complex float a = *in0++ + *in1++ * I;
    const _Complex float b = *in2++ + *in3++ * I;
    const _Complex float c = a * b;
    *out0++ = crealf(c);
    *out1++ = cimagf(c);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
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
  4, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which mixes two I/Q audio channels together"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Mixer_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::mixer", "1.0.0", "sdrtcl::mixer", _factory);
}
