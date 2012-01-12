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
#include "sdrkit_midi_queue.h"
/*
** Create a tap to buffer midi events.
*/

typedef struct {
  framework_t fw;
  midi_queue_t mq;
  int started;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  midi_queue_init(&data->mq);
  data->started = 0;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  void* midi_in = jack_port_get_buffer(framework_midi_input(data,0), nframes);
  jack_midi_event_t in_event;
  jack_nframes_t event_count = jack_midi_get_event_count(midi_in), event_index = 0, event_time = 0;
  jack_nframes_t last_frame = sdrkit_last_frame_time(arg);
  if (event_index < event_count) {
    jack_midi_event_get(&in_event, midi_in, event_index++);
    // event_time += in_event.time;
    event_time = in_event.time;
  } else {
    event_time = nframes+1;
  }
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    while (event_time == i) {
      if (data->started)
	midi_write(&data->mq, last_frame+i, in_event.size, in_event.buffer);
      if (event_index < event_count) {
	jack_midi_event_get(&in_event, midi_in, event_index++);
	// event_time += in_event.time;
	event_time = in_event.time;
      } else {
	event_time = nframes+1;
      }
    }
  }
  return 0;
}

static int _gets(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  /* return the collected events */
  _t *data = (_t *)clientData;
  Tcl_Obj *list = Tcl_NewListObj(0, NULL);
  while (midi_readable(&data->mq)) {
    Tcl_Obj *item = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(interp, item, Tcl_NewIntObj(midi_read_time(&data->mq)));
    Tcl_ListObjAppendElement(interp, item, Tcl_NewByteArrayObj(midi_read_bytes_ptr(&data->mq, midi_read_size(&data->mq)), midi_read_size(&data->mq)));
    Tcl_ListObjAppendElement(interp, list, item);
    midi_read_next(&data->mq);
  }
  Tcl_SetObjResult(interp, list);
  return TCL_OK;
}
static int _start(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  /* start collecting events */
  _t *data = (_t *)clientData;
  data->started = 1;
  return TCL_OK;
}
static int _stop(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  /* stop collecting events */
  _t *data = (_t *)clientData;
  data->started = 0;
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_command(clientData, interp, argc, objv);
}

static const fw_option_table_t _options[] = {
  { "-server", "server", "Server", "default",  fw_option_obj,	offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	offsetof(_t, fw.client_name), "jack client name" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
  { "gets",	 _gets },
  { "start",	 _start },
  { "stop",	 _stop },
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
  0, 0, 1, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Mtap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::mtap", "1.0.0", "sdrkit::mtap", _factory);
}
