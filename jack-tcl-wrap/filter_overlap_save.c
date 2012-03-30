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
#include "../sdrkit/filter_overlap_save.h"
#include "framework.h"

typedef filter_overlap_save_options_t options_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  filter_overlap_save_t ovsv;
} _t;

static void _update(_t *data) {
  if (data->modified) {
    data->modified = 0;
    filter_overlap_save_configure(&data->ovsv, &data->opts);
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->opts.sample_rate = sdrkit_sample_rate(arg);
  void *p = filter_overlap_save_init(&data->ovsv, &data->opts); if (p != &data->ovsv) return p;
  data->modified = 1;
  _update(data);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(data,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(data,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(data,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(data,1), nframes);
  AVOID_DENORMALS;
  _update(data);
  for (int i = nframes; --i >= 0; ) {
    float _Complex y = filter_overlap_save_process(&data->ovsv, *in0++ + I * *in1++);
    *out0++ = creal(y);
    *out1++ = cimag(y);
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)),
    Tcl_NewIntObj(data->ovsv.n_samples), Tcl_NewIntObj(data->ovsv.n_transforms),
    Tcl_NewIntObj(data->ovsv.length), Tcl_NewIntObj(data->ovsv.fftlen),
    NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(5, result));
  return TCL_OK;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.low_frequency != data->opts.low_frequency ||
      save.high_frequency != data->opts.high_frequency ||
      save.length != data->opts.length ||
      save.planbits != data->opts.planbits) {
    void *e = filter_overlap_save_preconfigure(&data->ovsv, &data->opts); if (e != &data->ovsv) {
      Tcl_SetResult(interp, e, TCL_STATIC);
      data->opts = save;
      return TCL_ERROR;
    }
    data->modified = 1;
  }
  return TCL_OK;
}

// the options that the command implements
static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-length", "length", "Length", "128",      fw_option_int,	fw_flag_none, offsetof(_t, opts.length),	      "length of filter" },
  { "-planbits","planbits","Planbits", "0",    fw_option_int,	fw_flag_none, offsetof(_t, opts.planbits),     "fftw planbits" },
  { "-low",    "low",    "Hertz",  "-5000",    fw_option_float,	fw_flag_none, offsetof(_t, opts.low_frequency),"filter low frequency cutoff" },
  { "-high",   "high",   "Hertz",  "+5000",    fw_option_float,	fw_flag_none, offsetof(_t, opts.high_frequency),"filter high frequency cutoff" },
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",   _get,   "fetch the current diagnostics" },
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "overlap save filter component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Filter_overlap_save_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::filter-overlap-save", "1.0.0", "sdrkit::filter-overlap-save", _factory);
}
