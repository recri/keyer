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
} options_t;

typedef struct {
  framework_t fw;
  ring_buffer_t rb;
  unsigned char buff[8192];
  int started;
  options_t opts;
} _t;

static int _writeable(_t *data, size_t bytes) {
  return ring_buffer_items_available_to_write(&data->rb) >= bytes+sizeof(jack_nframes_t)+sizeof(size_t);
}

static void _write(_t *data, jack_nframes_t frame, size_t size, unsigned char *buff) {
  ring_buffer_put(&data->rb, sizeof(frame), (unsigned char *)&frame);
  ring_buffer_put(&data->rb, sizeof(size), (unsigned char *)&size);
  ring_buffer_put(&data->rb, size, buff);
}

static int _read(_t *data, jack_nframes_t *framep, Tcl_Obj **bytes) {
  if (ring_buffer_items_available_to_read(&data->rb) < 3+sizeof(jack_nframes_t)+sizeof(size_t))
    return 0;
  int n = ring_buffer_get(&data->rb, sizeof(*framep), (unsigned char *)framep);
  size_t size;
  n += ring_buffer_get(&data->rb, sizeof(size), (unsigned char *)&size);
  *bytes = Tcl_NewObj();
  n += ring_buffer_get(&data->rb, size, Tcl_SetByteArrayLength(*bytes, size));
  return n;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *e = ring_buffer_init(&data->rb, sizeof(data->buff), data->buff); if (e != &data->rb) return e;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  framework_midi_event_init(&data->fw, NULL, nframes);
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    jack_midi_event_t event;
    int port;
    while (framework_midi_event_get(&data->fw, i, &event, &port)) {
      if (data->started && _writeable(data, event.size))
	_write(data, sdrkit_last_frame_time(arg)+i, event.size, event.buffer);
    }
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  if ( ! data->started)
    return fw_error_obj(interp, Tcl_ObjPrintf("midi-tap %s is not running", Tcl_GetString(objv[0])));

  /* return the collected events */
  Tcl_Obj *list = Tcl_NewListObj(0, NULL);
  jack_nframes_t frame;
  Tcl_Obj *bytes;
  while (_read(data, &frame, &bytes)) {
    Tcl_Obj *element[] = { Tcl_NewLongObj(frame), bytes, NULL };
    Tcl_ListObjAppendElement(interp, list, Tcl_NewListObj(2, element));
  }
  Tcl_SetObjResult(interp, list);
  return TCL_OK;
}
static int _start(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s start", Tcl_GetString(objv[0])));
  data->started = 1;
  return TCL_OK;
}
static int _state(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s state", Tcl_GetString(objv[0])));
  Tcl_SetObjResult(interp, Tcl_NewIntObj(data->started));
  return TCL_OK;
}
static int _stop(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s stop", Tcl_GetString(objv[0])));
  data->started = 0;
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get", _get, "get the available midi events from Jack" },
  { "start", _start, "start collecting events" },
  { "state", _state, "are we collecting events" },
  { "stop", _stop, "stop collecting events" },
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
  0, 0, 1, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which taps into the MIDI events in Jack"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Midi_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::midi-tap", "1.0.0", "sdrtcl::midi-tap", _factory);
}
