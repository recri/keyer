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

#include "framework.h"

#include <math.h>
#include <complex.h>

#include "../sdrkit/avoid_denormals.h"

/*
** a gain module which listens for a midi ptt signal
** and mutes the audio until the ptt goes low
*/
typedef struct {
  int verbose;
  int chan;
  int note;
  float dBgain;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  float _Complex gain;
  int mute;
  float ramp;
  float dramp;
} _t;

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;
    data->gain = powf(10.0f, data->dBgain / 20.0f);
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  dp->modified = 1;
  _update(dp);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  const _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  void *midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
  int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
  jack_midi_event_t in_event;
  // find out what input events we need to process
  if (in_event_index < in_event_count) {
    jack_midi_event_get(&in_event, midi_in, in_event_index++);
    in_event_time = in_event.time;
  } else {
    in_event_time = nframes+1;
  }
  _update(data);
  AVOID_DENORMALS;
  for (int i = nframes; --i >= 0; ) {
    /* process all midi input events at this sample frame */
    while (in_event_time == i) {
      if (in_event.size == 3) {
	const unsigned char channel = (in_event.buffer[0]&0xF)+1;
	const unsigned char command = in_event.buffer[0]&0xF0;
	const unsigned char note = in_event.buffer[1];
	if (channel == dp->opts.chan && note == dp->opts.note) {
	  if (command == MIDI_NOTE_ON) {
	    dp->mute = 1;
	    dp->ramp = 1.0;
	    dp->dramp = -0.001;
	  } else if (command == MIDI_NOTE_OFF) {
	    dp->mute = 0;
	    dp->ramp = 0.0;
	    dp->dramp = 0.001
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
    float _Complex z = data->gain * (*in0++ + I * *in1++);
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float dBgain = data->dBgain;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (data->dBgain != dBgain) data->gain = powf(10.0f, dBgain / 20.0f);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { "-gain",   "gain",   "Gain",   "-100.0",   fw_option_float,	offsetof(_t, dBgain),	      "noise level in dB" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
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
  2, 2, 0, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Gain_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::gain", "1.0.0", "sdrkit::gain", _factory);
}

