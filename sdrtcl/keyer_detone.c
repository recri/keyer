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
** keyer_detone uses a Goertzel filter to track the power on a specific tone
**
** a version with 128 stacked filters (one per MIDI note) might be nice once
** I understand how to decide what's on and what's off.
*/
#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "../dspmath/filter_goertzel.h"
#include "../dspmath/midi.h"
#include "framework.h"

typedef struct {
#include "framework_options_vars.h"
  filter_goertzel_options_t fg;
} options_t;
  
typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  filter_goertzel_t fg;
  float power;
} _t;

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;
    filter_goertzel_configure(&dp->fg, &dp->opts.fg);
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  dp->opts.fg.sample_rate = sdrkit_sample_rate(&dp->fw);
  void *p = filter_goertzel_preconfigure(&dp->fg, &dp->opts.fg); if (p != &dp->fg) return p;
  filter_goertzel_configure(&dp->fg, &dp->opts.fg);
  dp->power = 0.0f;
  return arg;
}

/*
** Jack
*/

static int _process(jack_nframes_t nframes, void *arg) {
  // get our data pointer
  _t *dp = (_t *)arg;
  // get the input pointer
  float *in = jack_port_get_buffer(framework_input(dp,0), nframes);
  // update parameters
  _update(dp);
  // for all frames in the buffer
  for(int i = 0; i < nframes; i++) {
    if (filter_goertzel_process(&dp->fg, *in++)) {
      // this may happen at dp->opts.fg.bandwidth or at lower frequency
      // need to decide whether this warrants a midi transition on output
      dp->power = dp->fg.power;
    }
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, Tcl_NewDoubleObj(data->power));
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.fg.hertz != save.fg.hertz || data->opts.fg.bandwidth != save.fg.bandwidth);
  if (data->modified) {
    void *e = filter_goertzel_preconfigure(&data->fg, &data->opts.fg); if (e != &data->fg) {
      data->opts = save;
      data->modified = 0;
      return fw_error_str(interp, e);
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-freq",      "frequency", "AFHertz", "800.0", fw_option_float, fw_flag_none, offsetof(_t, opts.fg.hertz),     "frequency to tune in Hz"  },
  { "-bandwidth", "bandwidth", "BWHertz", "100.0", fw_option_float, fw_flag_none, offsetof(_t, opts.fg.bandwidth), "bandwidth of output signal in Hz" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",   _get,   "fetch the current detected power of the filter" },
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
  1, 0, 0, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which converts midi key on/off events to dits and dahs"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_detone_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::detone", "1.0.0", "keyer::detone", _factory);
}
