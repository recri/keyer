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
#define FRAMEWORK_OPTIONS_MIDI 1
#include "../dspmath/dspmath.h"
#include "../dspmath/midi.h"
#include "framework.h"

/*
** a gain module which listens for a midi ptt signal
** and mutes the audio until the ptt goes low
*/
typedef struct {
#include "framework_options_vars.h"
  float dBgain;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  float gain;
  int mute;
  int transition;
  float ramp;
  float dramp;
} _t;

static void _update(_t *dp) {
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  dp->gain = dB_to_linear(dp->opts.dBgain);
  dp->mute = 0;
  dp->transition = 0;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  void *midi_in = jack_port_get_buffer(framework_midi_input(arg,0), nframes);
  int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
  jack_midi_event_t in_event;
  // find out what input events we need to process
  if (in_event_index < in_event_count) {
    jack_midi_event_get(&in_event, midi_in, in_event_index++);
    in_event_time = in_event.time;
  } else {
    in_event_time = nframes+1;
  }
  _update(dp);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    /* process all midi input events at this sample frame */
    while (in_event_time == i) {
      if (in_event.size == 3) {
	const unsigned char channel = (in_event.buffer[0]&0xF)+1;
	const unsigned char command = in_event.buffer[0]&0xF0;
	const unsigned char note = in_event.buffer[1];
	const unsigned char velocity = in_event.buffer[2];
	if (channel == dp->opts.chan && note == dp->opts.note+1) { /* ptt convention? */
	  if (MIDI_NOTE_ON && velocity > 0) {
	    dp->mute = 1;
	    dp->ramp = 1.000;
	    dp->dramp = -0.001;
	    dp->transition = 1000;
	  } else if (command == MIDI_NOTE_OFF || (command == MIDI_NOTE_ON && velocity == 0)) {
	    dp->mute = 0;
	    dp->ramp = 0.000;
	    dp->dramp = 0.001;
	    dp->transition = 1000;
	  }
	}
      }
      // look for another event
      if (in_event_index < in_event_count) {
	jack_midi_event_get(&in_event, midi_in, in_event_index++);
	in_event_time = in_event.time;
      } else {
	in_event_time = nframes;
      }
    }
    // process the audio
    float _Complex z = dp->gain * (*in0++ + I * *in1++);
    if (dp->transition != 0) {
      z *= dp->ramp;
      dp->ramp += dp->dramp;
      dp->transition -= 1;
    } else if (dp->mute) {
      z = 0.0f;
    }
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  float dBgain = dp->opts.dBgain;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (dp->opts.dBgain != dBgain) {
    dp->gain = dB_to_linear(dp->opts.dBgain);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-gain",   "gain",     "Gain",    "-30.0",   fw_option_float, 0, offsetof(_t, opts.dBgain),    "gain level in dB" },
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
  2, 2, 1, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component that translates a MIDI ptt signal to mute an audio channel"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Keyer_ptt_mute_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::keyer-ptt-mute", "1.0.0", "sdrtcl::keyer-ptt-mute", _factory);
}

