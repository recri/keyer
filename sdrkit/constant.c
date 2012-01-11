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

/*
** create a constant module which produces constant samples
** two scalar parameters, the real and imaginary
*/
typedef struct {
  framework_t fw;
  float real, imag;
} _t;

static void *_init(void *arg) {
  _t * data = (_t *)arg;
  data->real = 1.0f;
  data->imag = 0.0f;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  const _t * const data = (_t *)arg;
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  for (int i = nframes; --i >= 0; ) {
    *out0++ = data->real;
    *out1++ = data->imag;
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // fprintf(stderr, "%s:_command(%lx, %lx, %d, %lx)\n", __FILE__, (long)clientData, (long)interp, argc, (long)objv);
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", "constant", fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { "-real",   "real",   "Real",   "1.0",      fw_option_float,	offsetof(_t, real),	      "real part of constant produced" },
  { "-imag",   "imag",   "Imag",   "0.0",      fw_option_float,	offsetof(_t, imag),	      "imaginary part of constant produced" },
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
  2, 2, 0, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // fprintf(stderr, "%s: _command = %lx, template.command = %lx\n", __FILE__, (long)_command, (long)_template.command);
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}  

// the initialization function which installs the adapter factory
int DLLEXPORT Constant_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit_constant", "1.0.0", "sdrkit::constant", _factory);
}
