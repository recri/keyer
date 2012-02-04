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

/*
** delay i or q or neither samples by 1 sample time.
** useful for correcting input from Creative X-Fi
** or for converting a mono channel to iq.
*/
typedef struct {
  framework_t fw;
  int who_delay;
  float delayed_sample;
} _t;

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  float delayed_sample = data->delayed_sample;
  switch (data->who_delay) {
  case 0:			// no delay
    for (int i = nframes; --i >= 0; ) {
      *out0++ = *in0++;
      *out1++ = *in1++;
    }
    break;
  case 1:			// delay i
    for (int i = nframes; --i >= 0; ) {
      *out0++ = delayed_sample; delayed_sample = *in0++;
      *out1++ = *in1++;
    }
    break;
  case -1:			// delay q
    for (int i = nframes; --i >= 0; ) {
      *out0++ = *in0++;
      *out1++ = delayed_sample; delayed_sample = *in1++;
    }
    break;
  }
  data->delayed_sample = delayed_sample;
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-delay", "delay", "Delay", "0", fw_option_int, fw_flag_none, offsetof(_t,who_delay), "delay i (1), q (-1), or neither (0) by one sample" },
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which converts a monoaural audio channel into an I/Q audio channel pair"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_delay_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::iq-delay", "1.0.0", "sdrkit::iq-delay", _factory);
}
