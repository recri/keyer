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
#define FRAMEWORK_USES_INTERP 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "framework.h"
#include "../dspmath/ring_buffer.h"

/*
** Create a tap to buffer midi events.
*/

typedef struct {
#include "framework_options_vars.h"
  int transpose;
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
} _t;

static void *_init(void *arg) {
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  void *midi_in = jack_port_get_buffer(framework_midi_input(data,0), nframes);
  void *midi_out = jack_port_get_buffer(framework_midi_output(data,0), nframes);

  /* this is important, very strange if omitted */
  jack_midi_clear_buffer(midi_out);

  /* set up the midi event queue */
  framework_midi_event_init(&data->fw, NULL, nframes);

  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample frame */
    jack_midi_event_t event;
    int port;
    while (framework_midi_event_get(&data->fw, i, &event, &port)) {
      if (port != 0) continue; /* not sure how this might happen */
      /* decode the incoming event */
      if (event.size != 3) {
	jack_midi_event_write(midi_out, i, event.buffer, event.size);
	continue;
      }
      const unsigned char comm = event.buffer[0]&0xF0;
      const unsigned char chan = (event.buffer[0]&0xF)+1;
      const unsigned char note = event.buffer[1];
      if (chan != data->opts.chan) {
	jack_midi_event_write(midi_out, i, event.buffer, event.size);
	continue;
      }
      if (comm != MIDI_NOTE_ON && comm != MIDI_NOTE_OFF) {
	jack_midi_event_write(midi_out, i, event.buffer, event.size);
	continue;
      }
      unsigned char buffer[3] = { event.buffer[0], (note+data->opts.transpose) % 128, event.buffer[2] };
      jack_midi_event_write(midi_out, i, buffer, 3);
    }
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-transpose",     "note",      "Note",    "4",	    fw_option_int,     fw_flag_none,        offsetof(_t, opts.transpose),      "base midi note transpose" },
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
  0, 0, 1, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which transposes MIDI note events on a channel"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Midi_transpose_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::midi-transpose", "1.0.0", "sdrtcl::midi-transpose", _factory);
}
