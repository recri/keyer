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

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <errno.h>
#include <time.h>

#include <tcl.h>
#include <jack/jack.h>

static void ignore(const char *message) {}

static jack_client_t *get_client(Tcl_Interp *interp, char *server_name) {
  if (server_name == NULL) 
    if (getenv("JACK_DEFAULT_SERVER") != NULL)
      server_name = getenv("JACK_DEFAULT_SERVER");
    else
      server_name = "default";
  jack_set_error_function (ignore);
  jack_set_info_function (ignore);
  jack_status_t status;
  jack_client_t *client = jack_client_open("sdrkit", JackServerName, &status, server_name);
  if (client == NULL)
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_client_open(\"sdrkit\", JackServerName|JackUseExactName, ..., \"%s\") failed", server_name));
  return client;
}

static int list_ports(ClientData clientData, Tcl_Interp *interp) {
  jack_client_t *client = (jack_client_t *)clientData;
  Tcl_Obj *dict = Tcl_NewDictObj();
  Tcl_Obj *direction = Tcl_NewStringObj("direction", -1);
  Tcl_Obj *input = Tcl_NewStringObj("input", -1);
  Tcl_Obj *output = Tcl_NewStringObj("output", -1);
  Tcl_Obj *physical = Tcl_NewStringObj("physical", -1);
  Tcl_Obj *connections = Tcl_NewStringObj("connections", -1);
  const char **portv[] = {
    jack_get_ports (client, NULL, JACK_DEFAULT_AUDIO_TYPE, 0),
    jack_get_ports (client, NULL, JACK_DEFAULT_MIDI_TYPE, 0)
  };
  for (int p = 0; p < 2; p += 1)
    if (portv[p] != NULL) {
      for (int i = 0; portv[p][i] != NULL; i += 1) {
      jack_port_t *port = jack_port_by_name(client, portv[p][i]);
      if (port != NULL) {
	Tcl_Obj *pdict = Tcl_NewDictObj();
	int flags = jack_port_flags(port);
	Tcl_DictObjPut(interp, pdict, direction, flags & JackPortIsInput ? input : output );
	Tcl_DictObjPut(interp, pdict, physical, Tcl_NewIntObj(flags & JackPortIsPhysical ? 1 : 0));
	const char **connv = jack_port_get_all_connections(client, port);
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

static int connect_ports(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  jack_client_t *client = (jack_client_t *)clientData;
  for (int i = 0; i+1 < argc; i += 2) {
    int err = jack_connect(client, Tcl_GetString(objv[i]), Tcl_GetString(objv[i+1]));
  }
  return TCL_OK;
}

static int disconnect_ports(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  jack_client_t *client = (jack_client_t *)clientData;
  for (int i = 0; i+1 < argc; i += 2) {
    int err = jack_disconnect(client, Tcl_GetString(objv[i]), Tcl_GetString(objv[i+1]));
  }
  return TCL_OK;
}

static int finished(jack_client_t *client, int status) {
  if (client != NULL)
    jack_client_close(client);
  return status;
}

// the command which returns jack client information
// and implements port management
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  int i;
  jack_client_t *client = NULL;
  if (argc > 2 && strcmp(Tcl_GetString(objv[1]), "-server") == 0) {
    client = get_client(interp, Tcl_GetString(objv[2]));
    i = 3;
  } else {
    client = get_client(interp, NULL);
    i = 1;
  }
  if (client == NULL)
    return finished(client, TCL_ERROR);
  if (i == argc-1) {
    char *cmd = Tcl_GetString(objv[i]);
    if (strcmp(cmd, "list-ports") == 0) {
      return finished(client, list_ports(client, interp));
    }
    if (strcmp(cmd, "sample-rate") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_sample_rate(client)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "buffer-size") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_buffer_size(client)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "cpu-load") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewDoubleObj(jack_cpu_load(client)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "is-realtime") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_is_realtime(client)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "frame-time") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_frame_time(client)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "time") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_get_time()));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "version-string") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj(jack_get_version_string(), -1));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "client-name-size") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_client_name_size()));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "port-name-size") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_port_name_size()));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "port-type-size") == 0) {
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_port_type_size()));
      return finished(client, TCL_OK);
    }
  } else if (argc-i == 2) {
    char *cmd = Tcl_GetString(objv[i]);
    if (strcmp(cmd, "time-to-frames") == 0) {
      jack_time_t time;
      if (Tcl_GetLongFromObj(interp, objv[i+1], &time) != TCL_OK)
	return finished(client, TCL_ERROR);
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_time_to_frames(client, time)));
      return finished(client, TCL_OK);
    }
    if (strcmp(cmd, "frames-to-time") == 0) {
      jack_nframes_t frames;
      if (Tcl_GetIntFromObj(interp, objv[i+1], &frames) != TCL_OK)
	return finished(client, TCL_ERROR);
      Tcl_SetObjResult(interp, Tcl_NewIntObj(jack_frames_to_time(client, frames)));
      return finished(client, TCL_OK);
    }
  } else if (argc-i >= 3 && ((argc-i)&1)) {
    char *cmd = Tcl_GetString(objv[i]);
    if (strcmp(cmd, "connect") == 0) {
      return finished(client, connect_ports(client, interp, argc-2, objv+2));
    }
    if (strcmp(cmd, "disconnect") == 0) {
      return finished(client, disconnect_ports(client, interp, argc-2, objv+2));
    }
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-server servername] ("
					 "sample-rate|"
					 "buffer-size|"
					 "cpu-load|"
					 "is-realtime|"
					 "frame-time|"
					 "time|"
					 "version-string|"
					 "client-name-size|"
					 "port-name-size|"
					 "port-type-size|"
					 "time-to-frames time|"
					 "frames-to-time frame|"
					 "list-ports|"
					 "connect port1 port2 ...|"
					 "disconnect port1 port2)",
					 Tcl_GetString(objv[0])));
  return finished(client, TCL_ERROR);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_jack_Init(Tcl_Interp *interp) {
  // tcl stubs and tk stubs are needed for dynamic loading,
  // you must have this set as a compiler option
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, TCL_VERSION, 1) == NULL) {
    Tcl_SetResult(interp, "Tcl_InitStubs failed",TCL_STATIC);
    return TCL_ERROR;
  }
#endif
#ifdef USE_TK_STUBS
  if (Tk_InitStubs(interp, TCL_VERSION, 1) == NULL) {
    Tcl_SetResult(interp, "Tk_InitStubs failed",TCL_STATIC);
    return TCL_ERROR;
  }
#endif
  Tcl_PkgProvide(interp, "sdrkit", "1.0.0");
  Tcl_CreateObjCommand(interp, "sdrkit::jack", _command, NULL, NULL);
  return TCL_OK;
}

