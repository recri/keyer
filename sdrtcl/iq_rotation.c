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
** accumulate the average rotation of an IQ sample stream
** this will be positive if IQ are I and Q, and negative if
** IQ are Q and I.
*/
#define FRAMEWORK_USES_JACK 1

#include "../dspmath/iq_rotation.h"
#include "framework.h"

typedef struct {
  framework_t fw;
  iq_rotation_t r;
} _t;

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    iq_rotation_process(&data->r, *in0++ + *in1++ * I);
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, Tcl_NewDoubleObj(crealf(data->r.r)));
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

// the options that the command implements
static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",   _get,   "fetch the current average rotation" },
  { NULL }
};

// the template which describes this command
static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  NULL,				// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component to compute the I/Q channel rotation"
};

// the factory command which creates iq rotation commands
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_rotation_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::iq-rotation", "1.0.0", "sdrkit::iq-rotation", _factory);
}
