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

#include "sdrkit.h"
#include "sdrkit_midi_queue.h"
/*
** Create a tap to buffer midi events.
*/

typedef struct {
  SDRKIT_T_COMMON;
  midi_queue_t mq;
  char started;
} _t;

static void _init(void *arg) {
  _t *data = (_t *)arg;
  midi_queue_init(&data->mq);
  data->started = 0;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  void* midi_in = jack_port_get_buffer(data->port[0], nframes);
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

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc >= 2) {
    char *cmd = Tcl_GetString(objv[1]);
    if (strcmp(cmd, "get") == 0) {
      /* return the collected events */
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
    } else if (strcmp(cmd, "start") == 0) {
      /* start collecting events */
      data->started = 1;
      return TCL_OK;
    } else if (strcmp(cmd, "stop") == 0) {
      /* stop collecting events */
      data->started = 0;
      return TCL_OK;
    }
  }
  /* usage */
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s start|stop|get", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 0, 0, 1, 0, _command, _process, sizeof(_t), _init, _delete);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_mtap_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::mtap", _factory);
}
