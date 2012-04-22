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
#include "framework.h"
#include <fftw3.h>
#include "../sdrkit/window.h"
#include "../sdrkit/polyphase_fft.h"

/*
** Tap a possibly I/Q audio stream to produce a scalar meter value.
** choice of incoming stream treatment as:
**	abs_real, abs_imag, max_abs_real_abs_imag, or mag^2
** keep the max, the sum, and the decayed average for which ever
** is chosen, and return frame nframes max, sum, decayed average
** over the frame period.
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
} options_t;

typedef void (*reduce_function_t)(jack_nframes_t n, float *in0, float *in1, float *val, float *sum, float *decayed, const float decay, const float comp_decay);

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
  reduce_function_t reduce;
  float decay, comp_decay;
  float max_val, sum_val, decayed_val;
  jack_nframes_t frame;
  jack_nframes_t nframes;
} _t;

/*
** shared reduction pattern
*/
static void reduce_val(float val, float *max, float *sum, float *decayed, float decay, float comp_decay) {
    *max = maxf(*max, val); *sum += val; *decayed = *decayed * decay + val * comp_decay;
}  
/*
** four reduction functions
*/
static void reduce_abs_real(jack_nframes_t n, float *in0, float *in1, float *max, float *sum, float *decayed, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(absf(*in0++), max, sum, decayed, decay, comp_decay);
}
static void reduce_abs_imag(jack_nframes_t n, float *in0, float *in1, float *max, float *sum, float *decayed, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(absf(*in1++), max, sum, decayed, decay, comp_decay);
}
static void reduce_max_abs(jack_nframes_t n, float *in0, float *in1, float *max, float *sum, float *decayed, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(maxf(absf(*in0++), absf(*in1++)), max, sum, decayed, decay, comp_decay);
}
static void reduce_mag_squared(jack_nframes_t n, float *in0, float *in1, float *max, float *sum, float *decayed, float decay, float comp_decay) {
  for (int i = 0; i < n; i += 1) reduce_val(squaref(*in0++) + squaref(*in1++), max, sum, decayed, decay, comp_decay);
}
/*
** preconfigure a meter tap
*/
static void *_preconfigure(_t *data) {
  options_t *opts = &data->opts;
  preconf_t *prec = &data->prec;
  // process options
  if (opts->decay <= 0) return "decay constant must be greater than zero";
  char *reduce_type_str = Tcl_GetString(opts->result_type_obj);
  if (strcmp(reduce_type_str, "") == 0 || strcmp(reduce_type_str, "mag2") == 0) prec->reduce = reduce_mag_squared;
  else if (strcmp(reduce_type_str, "abs_real") == 0) prec->reduce = reduce_abs_real;
  else if (strcmp(reduce_type_str, "abs_imag") == 0) prec->reduce = reduce_abs_imag;
  else if (strcmp(reduce_type_str, "max_abs") == 0) prec->reduce = reduce_max_abs;
  else return "reduce must be one of mag2, abs_real, abs_imag, or max_abs";
  data->modified = 1;
  return data;
}

static void _configure(_t *data) {
  preconf_t *prec = &data->prec;
  data->reduce = prec->reduce;
  data->decay = prec->decay;
  data->comp_decay = 1.0f - data->decay;
  data->nframes = 0;
  data->max_val = 0;
  data->sum_val = 0;
  data->decayed_val = 0;
}

static void _update(_t *data) {
  if (data->modified) {
    _configure(data);
    data->modified = 0;
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
  data->reduce(nframes, in0, in1, &data->max_val, &data->sum_val, &data->decayed_val, data->decay, data->comp_decay);
  data->frame = sdrkit_last_frame_time(arg)+nframes;
  data->nframe += nframes;
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {

  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  if ( ! framework_is_active(clientData)) return fw_error_obj(interp, Tcl_ObjPrintf("%s is not active", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  if (data->modified) return fw_error_str(interp, "busy");

  // there's a race here.
  // double buffer the output
  jack_nframes_t frame = data->frame;
  jack_nframes_t nframes = data->nframes;
  float max_val = data->max_val;
  float sum_val = data->sum_val;
  float decayed_val = data->decayed_val;
  data->nframes = 0;
  data->max_val = 0.0f;
  data->sum_val = 0.0f;
  data->decayed_val = 0.0f;
  return fw_success_obj(interp, Tcl_NewListObj(5, (Tcl_Obj *[]){
	Tcl_NewLongObj(frame), Tcl_NewLongObj(nframes), Tcl_NewDoubleObj(max_val), Tcl_NewDoubleObj(sum_val), Tcl_NewDoubleObj(decayed_val), NULL
	  }));
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  Tcl_IncrRefCount(save.result_type_obj);
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.size != data->opts.size ||
      save.planbits != data->opts.planbits ||
      save.polyphase != data->opts.polyphase ||
      save.direction != data->opts.direction ||
      save.result_type_obj != data->opts.result_type_obj) {
    void *p = _preconfigure(data); if (p != data) {
      Tcl_DecrRefCount(data->opts.result_type_obj);
      data->opts = save;
      return fw_error_str(interp, p);
    }
    Tcl_DecrRefCount(save.result_type_obj);
    if ( ! framework_is_active(data) )
      _update(data);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-size",     "size",     "Samples",   "4096", fw_option_int, 0, offsetof(_t, opts.size),		"size of fft computed" },
  { "-planbits", "planbits", "Planbits",  "0",	  fw_option_int, 0, offsetof(_t, opts.planbits),	"fftw plan bits" },
  { "-direction","direction","Direction", "-1",	  fw_option_int, 0, offsetof(_t, opts.direction),	"fft direction, 1=inverse or -1=forward" },
  { "-polyphase","polyphase","Polyphase", "1",    fw_option_int, 0, offsetof(_t, opts.polyphase),	"polyphase fft, multiple of size to filter" },
  { "-result",   "result",   "Result",    "coeff",fw_option_obj, 0, offsetof(_t, opts.result_type_obj), "result type: coeff, mag, mag2, dB, short, char" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",	 _get,                    "get an audio buffer" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which taps baseband signals and computes a spectrum"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Spectrum_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::spectrum-tap", "1.0.0", "sdrkit::spectrum-tap", _factory);
}
