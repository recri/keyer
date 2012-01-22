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

#include "framework.h"

typedef struct {
  framework_t fw;
} _t;

static int _usage(Tcl_Interp *interp, char *string) {
  Tcl_SetResult(interp, string, TCL_STATIC);
  return TCL_ERROR;
}

static int _list_ports(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return _usage(interp, "jack-client list-ports");
  _t *dp = (_t *)clientData;
  Tcl_Obj *dict = Tcl_NewDictObj();
  Tcl_Obj *direction = Tcl_NewStringObj("direction", -1);
  Tcl_Obj *input = Tcl_NewStringObj("input", -1);
  Tcl_Obj *output = Tcl_NewStringObj("output", -1);
  Tcl_Obj *physical = Tcl_NewStringObj("physical", -1);
  Tcl_Obj *connections = Tcl_NewStringObj("connections", -1);
  const char **portv[] = {
    jack_get_ports (dp->fw.client, NULL, JACK_DEFAULT_AUDIO_TYPE, 0),
    jack_get_ports (dp->fw.client, NULL, JACK_DEFAULT_MIDI_TYPE, 0)
  };
  for (int p = 0; p < 2; p += 1)
    if (portv[p] != NULL) {
      for (int i = 0; portv[p][i] != NULL; i += 1) {
      jack_port_t *port = jack_port_by_name(dp->fw.client, portv[p][i]);
      if (port != NULL) {
	Tcl_Obj *pdict = Tcl_NewDictObj();
	int flags = jack_port_flags(port);
	Tcl_DictObjPut(interp, pdict, direction, flags & JackPortIsInput ? input : output );
	Tcl_DictObjPut(interp, pdict, physical, Tcl_NewIntObj(flags & JackPortIsPhysical ? 1 : 0));
	const char **connv = jack_port_get_all_connections(dp->fw.client, port);
	Tcl_Obj *list = Tcl_NewListObj(0, NULL);
	if (connv != NULL) {
	  for (int j = 0; connv[j] != NULL; j += 1)
	    Tcl_ListObjAppendElement(interp, list, Tcl_NewStringObj(connv[j], -1));
	  jack_free(connv);
	}
	Tcl_DictObjPut(interp, pdict, connections, list);
	Tcl_DictObjPut(interp, dict, Tcl_NewStringObj(portv[p][i], -1), pdict);
      }
    }
    jack_free(portv[p]);
  }
  Tcl_SetObjResult(interp, dict);
  return TCL_OK;
}
static int _sample_rate(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client sample-rate");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_sample_rate(dp->fw.client)));
  return TCL_OK;
}
static int _buffer_size(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client buffer-size");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_buffer_size(dp->fw.client)));
  return TCL_OK;
}
static int _cpu_load(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client cpu-load");
  Tcl_SetObjResult(interp, Tcl_NewDoubleObj(jack_cpu_load(dp->fw.client)));
  return TCL_OK;
}
static int _is_realtime(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client is-realtime");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_is_realtime(dp->fw.client)));
  return TCL_OK;
}
static int _frame_time(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client frame-time");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_frame_time(dp->fw.client)));
  return TCL_OK;
}
static int _time(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client time");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_time()));
  return TCL_OK;
}
static int _version(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client version");
  int major, minor, micro, proto;
  jack_get_version(&major, &minor, &micro, &proto);
  Tcl_Obj *result[] = {
    Tcl_NewIntObj(major), Tcl_NewIntObj(minor), Tcl_NewIntObj(micro), Tcl_NewIntObj(proto), NULL
  };
  Tcl_SetObjResult(interp, Tcl_NewListObj(4, result));
  return TCL_OK;
}
static int _version_string(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client version-string");
  Tcl_SetObjResult(interp, Tcl_NewStringObj(jack_get_version_string(), -1));
  return TCL_OK;
}
static int _client_name_size(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client client-name-size");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_client_name_size()));
  return TCL_OK;
}
static int _port_name_size(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client port-name-size");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_port_name_size()));
  return TCL_OK;
}
static int _port_type_size(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 2) return _usage(interp, "jack-client port-type-size");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_port_type_size()));
  return TCL_OK;
}
static int _time_to_frames(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 3) return _usage(interp, "jack-client time-to-frames time");
  jack_time_t time;
  if (Tcl_GetLongFromObj(interp, objv[2], &time) != TCL_OK) return  TCL_ERROR;
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_time_to_frames(dp->fw.client, time)));
  return TCL_OK;
}
static int _frames_to_time(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  if (argc != 3) return _usage(interp, "jack-client frames-to-time frames");
  jack_nframes_t frames;
  if (Tcl_GetIntFromObj(interp, objv[2], &frames) != TCL_OK) return TCL_ERROR;
  Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_frames_to_time(dp->fw.client, frames)));
  return TCL_OK;
}
static int _connect(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc-2 < 0 || ((argc-2)&1) != 0) return _usage(interp, "jack-client connect from to [...]");
  _t *dp = (_t *)clientData;
  for (int i = 2; i+1 < argc; i += 2) {
    int err = jack_connect(dp->fw.client, Tcl_GetString(objv[i]), Tcl_GetString(objv[i+1]));
    // FIX.ME - do something with this error return!
  }
  return TCL_OK;
}
static int _disconnect(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc-2 < 0 || ((argc-2)&1) != 0) return _usage(interp, "jack-client disconnect from to [...]");
  _t *dp = (_t *)clientData;
  for (int i = 2; i+1 < argc; i += 2) {
    int err = jack_disconnect(dp->fw.client, Tcl_GetString(objv[i]), Tcl_GetString(objv[i+1]));
    // FIX.ME - do something with this error return!
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
  { "sample-rate",_sample_rate, "get the jack server sample rate" },
  { "buffer-size",_buffer_size, "get the jack server buffer size" },
  { "cpu-load",   _cpu_load, "get the jack server cpu load percent" },
  { "is-realtime",_is_realtime, "get the jack server realtime status" },
  { "frame-time", _frame_time, "get the jack server approximate frame time" },
  { "time",	  _time, "get the jack server time in microseconds?" },
  { "version",	  _version, "get the jack server version" },
  { "version-string", _version_string, "get the jack server version string" },
  { "client-name-size", _client_name_size, "get the jack server client name size" },
  { "port-name-size", _port_name_size, "get the jack server port name size" },
  { "port-type-size", _port_type_size, "get the jack server port type size" },
  { "time-to-frames", _time_to_frames, "ask the jack server to convert time to frames" },
  { "frames-to-time", _frames_to_time, "ask the jack server to convert frames to time" },
  { "list-ports", _list_ports, "get a list of the ports open on the jack server" },
  { "connect", _connect, "connect ports on the jack server" },
  { "disconnect", _disconnect, "disconnect ports on the jack server" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  NULL,				// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  NULL,				// process callback
  0, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component that interacts with a Jack server"
};


// the command which returns jack client information
// and implements port management
// on the jack server it opened
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which install the jack-client factory
int DLLEXPORT Jack_client_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::jack-client", "1.0.0", "sdrkit::jack-client", _factory);
}

