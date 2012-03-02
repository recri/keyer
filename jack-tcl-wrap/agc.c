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
** the dttsp agc delays the signal by some number of samples,
** difficult to determine, while it figures out what the gain
** should be, even before these many reparameterizations
** get thrown in.
**
** a->sndx is the output index in a circular buffer,
** a->indx is the input index in the same buffer,
** a->fastindx is another index in the same buffer.
** the three indexes get initialized in a particular
** relationship when the agc is started, and they get
** incremented and reduced by buffer size on each
** iteration through the loop.
** then there are the codes from update which modifie
** rx[RL]->dttspagc.gen->sndx by itself. so there are
** bugs.
**
** really should track the agc level and run it through
** some tests to see what it does and doesn't do.
*/

#define FRAMEWORK_USES_JACK 1

#include "../sdrkit/agc.h"
#include "framework.h"
/*
** create an automatic gain control module
** many scalar parameters
*/

typedef struct {
  framework_t fw;
  int modified;
  agc_t agc;
} _t;
  
static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *p = agc_init(&data->agc, sdrkit_sample_rate(arg)); if (p != &data->agc) return p;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  for (int i = nframes; --i >= 0; ) {
    float _Complex y = agc_process(&data->agc, *in0++ + *in1++ * I);
    *out0++ = creal(y);
    *out1++ = cimag(y);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

// the options that the command implements
static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-fixed",   "fixed",   "Fixed",   "-100.0",   fw_option_float, 0,	offsetof(_t.opts, fixed), "fixed gain in dB" },
  { "-compress", "compress", "Compress",   "0",   fw_option_float, 0,	offsetof(_t.opts, compress), "gain compression in ??" },
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs, midi_buffers
  "implement an automatic gain control component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Agc_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::agc", "1.0.0", "sdrkit::agc", _factory);
}
