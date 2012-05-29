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

#include "../dspmath/oscillator.h"
#include "framework.h"

typedef struct {
  framework_t fw;
  oscillator_t o;
  int sample_rate;
  int modified;
  float hertz;
#ifndef NO_GAIN
  float dBgain;
  float gain;
#endif
} _t;

static void _update(_t *data) {
  if (data->modified) {
    data->modified = data->fw.busy = 0;
    oscillator_update(&data->o, data->hertz, data->sample_rate);
  }
}
  
static void *_init(void *arg) {
  _t * const data = (_t *)arg;
  data->modified = data->fw.busy = 0;
  // data->hertz = 440.0f;
  // data->dBgain = -30;
#ifndef NO_GAIN
  data->gain = dB_to_linear(data->dBgain);
#endif
  data->sample_rate = sdrkit_sample_rate(data);
  void *p = oscillator_init(&data->o, data->hertz, 0.0f, data->sample_rate); if (p != &data->o) return p;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  _update(data);
  for (int i = nframes; --i >= 0; ) {
    float complex z = oscillator_process(&data->o);
#ifndef NO_GAIN
    z *= data->gain;
#endif
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float hertz = data->hertz;
#ifndef NO_GAIN
  float dBgain = data->dBgain;
#endif
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->hertz = hertz;
#ifndef NO_GAIN
    data->dBgain = dBgain;
#endif
    return TCL_ERROR;
  }
  if (data->hertz != hertz) {
    /* if (fabsf(data->hertz) > sdrkit_sample_rate(data)/4) {
      data->hertz = hertz;
#ifndef NO_GAIN
      data->dBgain = dBgain;
#endif
      return fw_error_str(interp, "frequency is more than samplerate/4");
      } */
    data->modified = data->fw.busy = 1;
    if ( ! framework_is_active(data)) _update(data);
  }
#ifndef NO_GAIN
  if (data->dBgain != dBgain) {
    data->gain = dB_to_linear(data->dBgain);
  }
#endif
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-freq",   "frequency","Hertz","700.0",    fw_option_float, 0,	offsetof(_t, hertz),	      "frequency of oscillator in Hertz" },
#ifndef NO_GAIN
  { "-gain",   "gain",   "Gain",   "-30.0",    fw_option_float, 0,	offsetof(_t, dBgain),	      "gain in dB" },
#endif
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
  0, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which implements an I/Q oscillator"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT OSCILLATOR_INIT_NAME(Tcl_Interp *interp) {
  return framework_init(interp, OSCILLATOR_STRING_NAME, "1.0.0", OSCILLATOR_STRING_NAME, _factory);
}
