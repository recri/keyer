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

// must precede
#define _XOPEN_SOURCE 500
#include <stdlib.h>

#include <math.h>
#include "../sdrkit/avoid_denormals.h"

#include "framework.h"


/*
** make noise, specified dB level
*/
typedef struct {
  framework_t fw;
  float gain;
  float dBgain;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->dBgain = -30.0f;
  data->gain = powf(10.0f, data->dBgain / 20.0f);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    *out0++ = data->gain * 4 * (0.5 - (random() / (float)RAND_MAX));
    *out1++ = data->gain * 4 * (0.5 - (random() / (float)RAND_MAX));
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
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { "-gain",   "gain",   "Gain",   "-100.0",   fw_option_float,	offsetof(_t, dBgain),	      "noise level in dB" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
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
  0, 2, 0, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Noise_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::noise", "1.0.0", "sdrkit::noise", _factory);
}
