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

#include "../dspmath/dspmath.h"
#include "framework.h"
#include <fftw3.h>
#include "../dspmath/window.h"
#include "../dspmath/polyphase_fft.h"

/*
** Tap a possibly I/Q audio stream to produce a scalar meter value.
** choice of incoming stream treatment as:
**	abs_real, abs_imag, max_abs_real_abs_imag, or mag^2
** keep the max, the sum, and the decayed average for which ever
** is chosen, and return frame nframes max, sum, decayed average
** over the frame period.
**
** there is another meter value read directly from the agc.
*/

typedef enum {
  as_abs_real,
  as_abs_imag,
  as_max_abs_real_or_abs_imag,
  as_magnitude_squared
} reduce_type_t;

typedef struct {
  // parameters
  Tcl_Obj * reduce_type_obj;	/* size of fft requested */
  float decay;
  int period;
} options_t;

typedef struct {
  jack_nframes_t frame, nframes;
  float max_val, sum_val, decayed_val;
} summary_t;

typedef void (*reduce_function_t)(jack_nframes_t n, float *in0, float *in1, summary_t *vals, const float decay, const float comp_decay);

typedef struct {
  // computed results kept for get
  reduce_type_t reduce_type;
  // computed results copied into process callback data
  reduce_function_t reduce;
} preconf_t;

typedef struct {
  framework_t fw;
  options_t opts;
  preconf_t prec;
  int modified;
  int period;
  reduce_function_t reduce;
  float decay, comp_decay;
  summary_t results[4];
  int n_results;
} _t;

/*
** shared reduction pattern
*/
static void reduce_val(float val, summary_t *vals, float decay, float comp_decay) {
    vals->max_val = maxf(vals->max_val, val);
    vals->sum_val += val;
    vals->decayed_val = vals->decayed_val * decay + val * comp_decay;
}  
/*
** four reduction functions
*/
static void reduce_abs_real(jack_nframes_t n, float *in0, float *in1, summary_t *vals, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(fabsf(*in0++), vals, decay, comp_decay);
}
static void reduce_abs_imag(jack_nframes_t n, float *in0, float *in1, summary_t *vals, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(fabsf(*in1++), vals, decay, comp_decay);
}
static void reduce_max_abs(jack_nframes_t n, float *in0, float *in1, summary_t *vals, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(maxf(fabsf(*in0++), fabsf(*in1++)), vals, decay, comp_decay);
}
static void reduce_mag_squared(jack_nframes_t n, float *in0, float *in1, summary_t *vals, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(squaref(*in0++) + squaref(*in1++), vals, decay, comp_decay);
}
/*
** preconfigure a meter tap
*/
static void *_preconfigure(_t *data) {
  options_t *opts = &data->opts;
  preconf_t *prec = &data->prec;
  // process options
  if (opts->decay <= 0) return "decay constant must be greater than zero";
  char *reduce_type_str = Tcl_GetString(opts->reduce_type_obj);
  if (strcmp(reduce_type_str, "") == 0 || strcmp(reduce_type_str, "mag2") == 0) prec->reduce = reduce_mag_squared;
  else if (strcmp(reduce_type_str, "abs_real") == 0) prec->reduce = reduce_abs_real;
  else if (strcmp(reduce_type_str, "abs_imag") == 0) prec->reduce = reduce_abs_imag;
  else if (strcmp(reduce_type_str, "max_abs") == 0) prec->reduce = reduce_max_abs;
  else return "reduce must be one of mag2, abs_real, abs_imag, or max_abs";
  data->modified = data->fw.busy = 1;
  return data;
}

static void _configure(_t *data) {
  data->period = data->opts.period;
  data->reduce = data->prec.reduce;
  data->decay = data->opts.decay;
  data->comp_decay = 1.0f - data->decay;
  data->n_results = 0;
  data->results[data->n_results&3] = (summary_t){ 0 };
}

static void _update(_t *data) {
  if (data->modified) {
    _configure(data);
    data->modified = data->fw.busy = 0;
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *p = _preconfigure(data); if (p != data) return p;
  _update(data);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  _update(data);
  data->reduce(nframes, in0, in1, &data->results[data->n_results&3], data->decay, data->comp_decay);
  data->results[data->n_results&3].frame = sdrkit_last_frame_time(arg)-data->results[data->n_results&3].nframes;
  data->results[data->n_results&3].nframes += nframes;
  if (data->results[data->n_results&3].nframes >= data->period) {
    data->n_results += 1;
    data->results[data->n_results&3] = (summary_t){ 0 };
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  if ( ! framework_is_active(clientData)) return fw_error_obj(interp, Tcl_ObjPrintf("%s is not active", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  if ((data->n_results-1) < 0) return fw_error_str(interp, "busy");
  summary_t result = data->results[(data->n_results-1)&3];
  return fw_success_obj(interp, Tcl_NewListObj(5, (Tcl_Obj *[]){
	Tcl_NewLongObj(result.frame), Tcl_NewLongObj(result.nframes),
	  Tcl_NewDoubleObj(result.max_val), Tcl_NewDoubleObj(result.sum_val), Tcl_NewDoubleObj(result.decayed_val),
	  NULL
	  }));
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  Tcl_IncrRefCount(save.reduce_type_obj);
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.reduce_type_obj != data->opts.reduce_type_obj ||
      save.decay != data->opts.decay) {
    void *p = _preconfigure(data); if (p != data) {
      Tcl_DecrRefCount(data->opts.reduce_type_obj);
      data->opts = save;
      return fw_error_str(interp, p);
    }
    Tcl_DecrRefCount(save.reduce_type_obj);
    if ( ! framework_is_active(data) )
      _update(data);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-period",   "period",   "Period",    "4096",  fw_option_int,   0, offsetof(_t, opts.period),	   "samples to accumulate for meter measurement" },
  { "-decay",    "decay",    "Decay",     "0.999", fw_option_float, 0, offsetof(_t, opts.decay),	   "amount of decayed average retained at each sample" },
  { "-reduce",   "reduce",   "Reduce",    "mag2",  fw_option_obj,   0, offsetof(_t, opts.reduce_type_obj), "reduction applied to samples: abs_real, abs_imag, max_abs, mag2" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get", _get, "get a meter record" },
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
  2, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which taps baseband signals and computes meter values"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Meter_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::meter-tap", "1.0.0", "sdrtcl::meter-tap", _factory);
}
