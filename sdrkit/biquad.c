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

#include <complex.h>
#include "../dspkit/avoid_denormals.h"
#include "../dspkit/biquad_filter.h"

typedef struct {
  framework_t fw;
  biquad_filter_t bq;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  return biquad_filter_init(&data->bq);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    float _Complex y = biquad_filter(&data->bq, *in0++ + I * *in1++);
    *out0++ = creal(y);
    *out1++ = cimag(y);
  }
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

// the options that the command implements
// w(0) = x - a1*w(1) + a2*w(2); y = b0*w(0) + b1*w(1) + b2*w(2)
static const fw_option_table_t _options[] = {
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { "-a1",     "tap",    "Tap",    "0.0",      fw_option_float,	offsetof(_t, bq.a1),	      "coefficient a1" },
  { "-a2",     "tap",    "Tap",    "0.0",      fw_option_float,	offsetof(_t, bq.a2),	      "coefficient a2" },
  { "-b0",     "tap",    "Tap",    "0.0",      fw_option_float,	offsetof(_t, bq.b0),	      "coefficient b0" },
  { "-b1",     "tap",    "Tap",    "0.0",      fw_option_float,	offsetof(_t, bq.b1),	      "coefficient b1" },
  { "-b2",     "tap",    "Tap",    "0.0",      fw_option_float,	offsetof(_t, bq.b2),	      "coefficient b2" },
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
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
  2, 2, 0, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Biquad_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::biquad", "1.0.0", "sdrkit::biquad", _factory);
}
