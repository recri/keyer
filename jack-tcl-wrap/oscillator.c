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

/*
** This should be widget configure|cget|start|stop
** options: -frequency hertz -phase angle -gain dB
** actually, phase doesn't work as an option
*/

#include <math.h>
#include <complex.h>

#include "framework.h"
#include "../sdrkit/oscillator.h"

typedef struct {
  framework_t fw;
  oscillator_t o;
  int modified;
  float hertz;
  float dBgain;
  float gain;
  int sample_rate;
} _t;

static void _update(_t *data) {
  if (data->modified) {
    data->modified = 0;
    oscillator_update(&data->o, data->hertz, data->sample_rate);
    data->gain = powf(10, data->dBgain / 20);
  }
}
  
static void *_init(void *arg) {
  _t * const data = (_t *)arg;
  data->modified = 0;
  data->hertz = 440.0f;
  data->dBgain = -30;
  data->gain = powf(10, data->dBgain / 20);
  data->sample_rate = sdrkit_sample_rate(data);
  void *p = oscillator_init(&data->o, data->hertz, data->sample_rate); if (p != &data->o) return p;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  for (int i = nframes; --i >= 0; ) {
    _update(data);
    float _Complex z = data->gain * oscillator(&data->o);
    *out0++ = creal(z);
    *out1++ = cimag(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float dBgain = data->dBgain, hertz = data->hertz;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (data->dBgain != dBgain) {
    data->modified = 1;
  }
  if (data->hertz != hertz) {
    if (fabsf(data->hertz) > sdrkit_sample_rate(data)/4) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("frequency %.1fHz is more than samplerate/4", data->hertz));
      data->hertz = hertz;
      data->dBgain = dBgain;
      return TCL_ERROR;
    }
    data->modified = 1;
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { "-gain",   "gain",   "Gain",   "-30.0",    fw_option_float,	offsetof(_t, dBgain),	      "gain in dB" },
  { "-freq",   "frequency","Hertz","700.0",    fw_option_float,	offsetof(_t, hertz),	      "frequency of oscillator in Hertz" },
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
int DLLEXPORT Oscillator_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::oscillator", "1.0.0", "sdrkit::oscillator", _factory);
}
