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

  keyer_decode reads midi note on and note off, infers a dit clock,
  and produces a string of dits, dahs, and spaces.
    
  It currently gets confused if it starts on something that's all
  dah's and spaces, so I'm cheating and sending the wpm from the
  keyers.  It should wait until it's seen both dits and dahs before
  making its first guesses.

*/

#include "framework.h"
#include "../sdrkit/midi.h"

typedef filter_goertzel_options_t options_t;
  
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
    filter_goertzel_configure(&dp->fg, &dp->opts);
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  void *p = ring_buffer_init(&dp->ring, RING_SIZE, dp->buff); if (p != &dp->ring) return p;
  dp->detone = (detone_t){ 0, 6000, 1, 1, 1, 1, 1 };
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
    float x = filter_goertzel_process(&dp->fg, *in++);
    if (x != dp->power) {
      // this may happen at dp->opts.bandwidth or at lower frequency
      // need to decide whether this warrants a midi transition on output
      dp->power = x;
    }
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.hertz != save.hertz || data->opts.bandwidth != save.bandwidth);
  if (data->modified) {
    void *e = filter_goertzel_preconfigure(&data->fg, &data->opts); if (e != &data->fg) {
      data->opts = save;
      data->modified = 0;
      Tcl_SetResult(interp, (char *)e, TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-chan",      "channel",   "Channel", "1",     fw_option_int,   fw_flag_none, offsetof(_t, opts.chan),      "midi channel used for keyer" },
  { "-note",      "note",      "Note",    "0",	   fw_option_int,   fw_flag_none, offsetof(_t, opts.note),      "base midi note used for keyer" },
  { "-freq",      "freq",      "AFHertz", "800.0", fw_option_float, fw_flag_none, offsetof(_t, opts.hertz),     "frequency to tune in Hz"  },
  { "-bandwidth", "bandwidth", "BWHertz", "100.0", fw_option_float, fw_flag_none, offsetof(_t, opts.bandwidth), "bandwidth of output signal in Hz" },
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
  1, 0, 0, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which converts midi key on/off events to dits and dahs"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_detone_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::detone", "1.0.0", "keyer::detone", _factory);
}
