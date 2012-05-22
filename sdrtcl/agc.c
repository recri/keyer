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

#include "../dspmath/agc.h"
#include "framework.h"

/*
** agc canned modes
*/
typedef enum {
  LONG = 0,
  SLOW = 1,
  MEDIUM = 2,
  FAST = 3,
  LEVELER = 4
} agc_mode_t;

static fw_option_custom_t agc_mode_custom_option[] = {
  { "long", LONG }, { "slow", SLOW }, { "medium", MEDIUM }, { "fast", FAST }, { "leveler", LEVELER },
  { NULL, -1 }
};
/*
** create an automatic gain control module
** many scalar parameters
*/

typedef struct {
  framework_t fw;
  int modified;
  agc_mode_t mode;
  agc_options_t opts;
  agc_t agc;
} _t;
  
static void _delete(void *arg) {
  _t *data = (_t *)arg;
  agc_delete(&data->agc);
}

static void _update(_t *data) {
  if (data->modified) {
    data->modified = data->fw.busy = 0;
    agc_configure(&data->agc, &data->opts);
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->opts.sample_rate = sdrkit_sample_rate(arg);
  void *p = agc_init(&data->agc, &data->opts); if (p != &data->agc) return p;
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
    float complex y = agc_process(&data->agc, *in0++ + *in1++ * I);
    *out0++ = crealf(y);
    *out1++ = cimagf(y);
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(jack_frame_time(data->fw.client)),
    Tcl_NewDoubleObj(data->agc.now_linear),
    NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
  return TCL_OK;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  agc_mode_t save_mode = data->mode;
  agc_options_t save_opts = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  if (data->mode != save_mode) {
    switch (data->mode) {
    case LONG:    data->opts.attack = 2; data->opts.decay = 2000; data->opts.hang_time = 750; data->opts.fast_hang_time = 100; break;
    case SLOW:    data->opts.attack = 2; data->opts.decay =  500; data->opts.hang_time = 500; data->opts.fast_hang_time = 100; break;
    case MEDIUM:  data->opts.attack = 2; data->opts.decay =  250; data->opts.hang_time = 250; data->opts.fast_hang_time = 100; break;
    case FAST:    data->opts.attack = 2; data->opts.decay =  100; data->opts.hang_time = 100; data->opts.fast_hang_time = 100; break;
    case LEVELER: data->opts.attack = 2; data->opts.decay =  500; data->opts.hang_time = 500; data->opts.fast_hang_time = 100;
      data->opts.target = 1.1; data->opts.max_linear = 5.62; data->opts.min_linear = 1.0; break;
    }
    void *e = agc_preconfigure(&data->agc, &data->opts); if (e != &data->agc) {
      Tcl_SetResult(interp, e, TCL_STATIC);
      data->mode = save_mode;
      data->opts = save_opts;
      return TCL_ERROR;
    }
    data->modified = data->fw.busy = 1;
  } else if (save_opts.target != data->opts.target ||
	     save_opts.attack != data->opts.attack ||
	     save_opts.decay != data->opts.decay ||
	     save_opts.slope != data->opts.slope ||
	     save_opts.hang_time != data->opts.hang_time ||
	     save_opts.fast_hang_time != data->opts.fast_hang_time ||
	     save_opts.max_linear != data->opts.max_linear ||
	     save_opts.min_linear != data->opts.min_linear ||
	     save_opts.hang_linear != data->opts.hang_linear) {
    void *e = agc_preconfigure(&data->agc, &data->opts); if (e != &data->agc) {
      Tcl_SetResult(interp, e, TCL_STATIC);
      data->opts = save_opts;
      return TCL_ERROR;
    }
    data->modified = data->fw.busy = 1;
  }
  if (data->modified && ! data->fw.activated)
    _update(data);
  return TCL_OK;
}

// the options that the command implements
static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-target",  "level",  "Level", "1.0",   fw_option_float, 0, offsetof(_t, opts.target),	  "target sample level" },
  { "-attack",  "ms",	  "Ms",	   "2.0",   fw_option_float, 0, offsetof(_t, opts.attack),	  "attack time in milliseconds" },
  { "-decay",   "ms",	  "Ms",	   "500",   fw_option_float, 0, offsetof(_t, opts.decay),	  "decay time in milliseconds" },
  { "-slope",   "slope",  "Slope", "1.0",   fw_option_float, 0, offsetof(_t, opts.slope),	  "slope of gain change" },
  { "-hang",    "ms",	  "Ms",	   "500",   fw_option_float, 0, offsetof(_t, opts.hang_time),	  "hang time in milliseconds" },
  { "-fasthang","ms",     "Ms",	   "100",   fw_option_float, 0, offsetof(_t, opts.fast_hang_time),"fast hang time in milliseconds" },
  { "-max",     "linear", "Linear","1e+4",  fw_option_float, 0, offsetof(_t, opts.max_linear),	  "maximum linear gain applied" },
  { "-min",     "linear", "Linear","1e-4",  fw_option_float, 0, offsetof(_t, opts.min_linear),	  "minimum linear gain applied" },
  { "-threshold","linear", "Linear","1.0",  fw_option_float, 0, offsetof(_t, opts.hang_linear),	  "hang cancellation linear gain threshold" },
  { "-mode",    "mode",   "Mode",  "slow",  fw_option_custom,0, offsetof(_t, mode),
    "mode, one of long, slow, medium, fast, or leveler", agc_mode_custom_option },
  { NULL }
};

// the subcommands implemented by this command
static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get", _get, "get the raw linear gain" },
  { NULL }
};

// the template which describes this command
static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs, midi_buffers
  "implement dttsp automatic gain control"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Agc_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::agc", "1.0.0", "sdrtcl::agc", _factory);
}
