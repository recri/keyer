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
#include "../sdrkit/iq_correct.h"
#include "framework.h"

/*
** combined rf input block:
** swap iq; delay i or q by sample; iq correct; rf gain
*/
typedef struct {
  int swap;
  int who_delay;
  iq_correct_options_t iqo;
  float mu;
  float dBgain;
} options_t;

#define SWAP	1
#define DELAY_I 2
#define DELAY_Q 4
#define CORRECT 8

typedef struct {
  framework_t fw;
  options_t opts;
  int mode;
  float delayed_sample;
  iq_correct_t iqb;
  float gain;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e = iq_correct_init(&data->iqb, &data->opts.iqo); if (e != &data->iqb) return e;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0;
  float *in1;
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);

  if (data->mode & SWAP) {
    in0 = jack_port_get_buffer(framework_input(data,1), nframes);
    in1 = jack_port_get_buffer(framework_input(data,0), nframes);
  } else {
    in0 = jack_port_get_buffer(framework_input(data,0), nframes);
    in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  }

  AVOID_DENORMALS;

  switch (data->mode & ~SWAP) {

  case 0:
    for (int i = nframes; --i >= 0; ) {
      float complex y = *in0++ + *in1++ * I;
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;

  case DELAY_I:
    for (int i = nframes; --i >= 0; ) {
      float complex y = data->delayed_sample + *in1++ * I; data->delayed_sample = *in0++;
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;

  case DELAY_Q:
    for (int i = nframes; --i >= 0; ) {
      float complex y = *in0++ + data->delayed_sample * I; data->delayed_sample = *in1++;
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;

  case CORRECT:
    for (int i = nframes; --i >= 0; ) {
      float complex x = *in0++ + *in1++ * I;
      float complex y = iq_correct_process(&data->iqb, x);
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;

  case CORRECT|DELAY_I:
    for (int i = nframes; --i >= 0; ) {
      float complex x = data->delayed_sample + *in1++ * I; data->delayed_sample = *in0++;
      float complex y = iq_correct_process(&data->iqb, x);
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;

  case CORRECT|DELAY_Q:
    for (int i = nframes; --i >= 0; ) {
      float complex x = *in0++ + data->delayed_sample * I; data->delayed_sample = *in1++;
      float complex y = iq_correct_process(&data->iqb, x);
      *out0++ = data->gain * crealf(y); *out1++ = data->gain * cimagf(y);
    }
    break;
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)),
    Tcl_NewDoubleObj(crealf(data->iqb.w)), Tcl_NewDoubleObj(cimagf(data->iqb.w)),
    NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(3, result));
  return TCL_OK;
}

static int _reset(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s reset", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  data->iqb.w = 0.0f;
  return TCL_OK;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  if (save.swap != data->opts.swap ||
      save.who_delay != data->opts.who_delay ||
      save.iqo.mu != data->opts.iqo.mu ||
      save.dBgain != data->opts.dBgain) {
    if (data->opts.who_delay < -1 || data->opts.who_delay > 1) {
      data->opts = save;
      Tcl_SetResult(interp, "invalid delay, must be -1, 0, or 1", TCL_STATIC);
      return TCL_ERROR;
    }
    if (save.iqo.mu != data->opts.iqo.mu) {
      void *e = iq_correct_preconfigure(&data->iqb, &data->opts.iqo);
      if (e != &data->iqb) {
	data->opts = save;
	return fw_error_str(interp, e);
      }
      iq_correct_configure(&data->iqb, &data->opts.iqo);
    }
    data->mode = 0;
    if (data->opts.swap) data->mode |= SWAP;
    if (data->opts.who_delay != 0) data->mode |= data->opts.who_delay > 0 ? DELAY_I : DELAY_Q;
    if (data->opts.mu != 0) data->mode |= CORRECT;
    data->gain = dB_to_linear(data->opts.dBgain);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-swap", "swap", "Swap", "0", fw_option_boolean, fw_flag_none, offsetof(_t,opts.swap), "swap i and q or leave them alone" },
  { "-delay", "delay", "Delay", "0", fw_option_int, fw_flag_none, offsetof(_t,opts.who_delay), "delay i (1), q (-1), or neither (0) by one sample" },
  { "-mu", "mu", "Mu", "0.25", fw_option_float, 0, offsetof(_t, opts.iqo.mu),	    "adaptation factor, larger is faster" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",   _get,   "fetch the current adaptive filter coefficients" },
  { "reset", _reset, "reset the current adaptive filter coefficients to zero" },
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs
  "a component which swaps the I/Q channels"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Input_block_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::input-block", "1.0.0", "sdrkit::input-block", _factory);
}
