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

#include "../sdrkit/dmath.h"
#include "../sdrkit/demod_am.h"
#include "../sdrkit/demod_sam.h"
#include "../sdrkit/demod_fm.h"
#include "framework.h"

/*
** demodulatation, gain, stereo conversion
*/
typedef enum {
  CW = 0,
  SSB = 1,
  AM = 2,
  SAM = 3,
  FM = 4
} demod_t;

fw_option_custom_t demod_option[] = {
  { "cw", CW }, { "ssb", SSB }, { "am", AM }, { "sam", SAM }, { "fm", FM },
  { NULL, -1 }
};

typedef struct {
  framework_t fw;
  float _Complex gain;
  float dBgain;
  demod_t mode;
  demod_am_t am;
  demod_sam_t sam;
  demod_fm_t fm;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e;
  data->gain = dB_to_linear(data->dBgain);
  e = demod_am_init(&data->am); if (e != &data->am) return e;
  e = demod_sam_init(&data->sam, sdrkit_sample_rate(&data->fw)); if (e != &data->sam) return e;
  e = demod_fm_init(&data->fm, sdrkit_sample_rate(&data->fw)); if (e != &data->fm) return e;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  AVOID_DENORMALS;
  switch (data->mode) {
  case CW:
    for (int i = nframes; --i >= 0; ) {
      float _Complex z = data->gain * (*in0++ + I * *in1++);
      *out0++ = crealf(z);
      *out1++ = cimagf(z);
    }
    break;
  case SSB:
    for (int i = nframes; --i >= 0; ) {
      float _Complex z = data->gain * (*in0++ + I * *in1++);
      *out0++ = crealf(z);
      *out1++ = cimagf(z);
    }
    break;
  case AM:
    for (int i = nframes; --i >= 0; ) {
      float y = data->gain * demod_am_process(&data->am, *in0++ + I * *in1++);
      *out0++ = y;
      *out1++ = y;
    }
    break;
  case SAM:
    for (int i = nframes; --i >= 0; ) {
      float y = data->gain * demod_sam_process(&data->sam, *in0++ + I * *in1++);
      *out0++ = y;
      *out1++ = y;
    }
    break;
  case FM:
    for (int i = nframes; --i >= 0; ) {
      float y = data->gain * demod_fm_process(&data->fm, *in0++ + I * *in1++);
      *out0++ = y;
      *out1++ = y;
    }
    break;
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float dBgain = data->dBgain;
  demod_t mode = data->mode;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->dBgain = dBgain;
    data->mode = mode;
    return TCL_ERROR;
  }
  if (data->dBgain != dBgain) data->gain = dB_to_linear(data->dBgain);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-gain",   "gain",   "Gain",   "-100.0",   fw_option_float, 0,	offsetof(_t, dBgain),	      "gain in dB" },
  { "-mode",   "mode",   "Mode",   "cw",       fw_option_custom,  0,	offsetof(_t, mode),           "mode: cw, ssb, am, sam, or fm", demod_option },
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a demodulation block component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Demod_block_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::demod-block", "1.0.0", "sdrkit::demod-block", _factory);
}

