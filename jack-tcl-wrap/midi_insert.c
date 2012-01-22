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
#include "../sdrkit/midi_buffer.h"

/*
** Insert midi events into Jack.
*/

typedef struct {
  framework_t fw;
  midi_buffer_t midi;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  midi_buffer_init(&data->midi);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void* midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  jack_midi_event_t event;

  // find out what there is to do
  framework_midi_event_init(&dp->fw, &dp->midi, nframes);

  // clear the jack output buffer
  jack_midi_clear_buffer(midi_out);

  // for each frame in this callback
  for(int i = 0; i < nframes; i += 1) {
    // process all midi output events at this sample frame
    int port;
    while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
      if (event.size != 0) {
	unsigned char* buffer = jack_midi_event_reserve(midi_out, i, event.size);
	if (buffer == NULL) {
	  fprintf(stderr, "%s:%d: jack won't buffer %ld midi bytes!\n", __FILE__, __LINE__, event.size);
	} else {
	  memcpy(buffer, event.buffer, event.size);
	}
      }
    }
  }
  return 0;
}

static int _puts(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s puts string", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  _t *data = (_t *)clientData;
  int n;
  unsigned char *p = Tcl_GetByteArrayFromObj(objv[2], &n);
  if (n > 0) {
    if (midi_buffer_write_command(&data->midi, 0, p, n) < 0) {
      Tcl_SetResult(interp, "error writing midi command", TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "puts",	 _puts, "put a binary MIDI packet into Jack" },
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
  0, 0, 0, 1, 1,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component to insert MIDI events into the Jack computational graph"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Midi_insert_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::midi-insert", "1.0.0", "sdrkit::midi-insert", _factory);
}
