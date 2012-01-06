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
#ifndef SDRKIT_H
#define SDRKIT_H

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#define __USE_XOPEN 1
#include <math.h>
#include <errno.h>
#include <time.h>
#include <complex.h>

#include <tcl.h>
#include <jack/jack.h>

/* this should be better encapsulated against conflict with client definitions */
#define SDRKIT_T_COMMON				\
  jack_client_t *client;			\
  char n_inputs;				\
  char n_outputs;				\
  char n_midi_inputs;				\
  char n_midi_outputs;				\
  jack_port_t **port;				\
  void (*command_delete)(void *)

typedef struct {
  SDRKIT_T_COMMON;
} sdrkit_t;

static int sdrkit_sample_rate(void *_sdrkit) {
  return (int)jack_get_sample_rate(((sdrkit_t *)_sdrkit)->client);
}

static jack_nframes_t sdrkit_buffer_size(void *_sdrkit) {
  return jack_get_buffer_size(((sdrkit_t *)_sdrkit)->client);
}

static char *sdrkit_client_name(void *_sdrkit) {
  return jack_get_client_name(((sdrkit_t *)_sdrkit)->client);
}

/* use this one from outside the process_callback */
static jack_nframes_t sdrkit_frame_time(void *_sdrkit) {
  return jack_frame_time(((sdrkit_t *)_sdrkit)->client);
}

/* use this one inside the process_callback, for the first frame in the callback */
static jack_nframes_t sdrkit_last_frame_time(void *_sdrkit) {
  return jack_last_frame_time(((sdrkit_t *)_sdrkit)->client);
}

/* translates frames to microseconds */
static jack_time_t sdrkit_frames_to_time(void *_sdrkit, jack_nframes_t frames) {
  return jack_frames_to_time(((sdrkit_t *)_sdrkit)->client, frames);
}

/* translates microseconds to frames */
static jack_nframes_t sdrkit_time_to_frames(void *_sdrkit, jack_time_t time) {
  return jack_time_to_frames(((sdrkit_t *)_sdrkit)->client, time);
}

/* get the jack time base */
static jack_time_t sdrkit_get_time() {
  return jack_get_time();
}

/* get a float argument from a Tcl_Obj */
static int sdrkit_get_float(Tcl_Interp *interp, Tcl_Obj *obj, float *result) {
  double tmp;
  if (Tcl_GetDoubleFromObj(interp, obj, &tmp) != TCL_OK)
    return TCL_ERROR;
  *result = tmp;
  return TCL_OK;
}

/* return a list of values */
static int sdrkit_return_values(Tcl_Interp *interp, Tcl_Obj *values) {
  int argc;
  const char **argv;
  if (Tcl_SplitList(interp, Tcl_GetString(values), &argc, &argv) == TCL_OK) {
    Tcl_Obj *list = Tcl_NewListObj(0, NULL);
    for (int i = 0; i < argc; i += 1)
      Tcl_ListObjAppendElement(interp, list, Tcl_NewStringObj(argv[i], -1));
    Tcl_Free((char *)argv);
    Tcl_SetObjResult(interp, list);
    return TCL_OK;
  }
  return TCL_ERROR;
}

/* delete a dsp module cleanly */
static void sdrkit_delete(void *_sdrkit) {
  sdrkit_t *dsp = (sdrkit_t *)_sdrkit;
  // fprintf(stderr, "sdrkit_delete(%p)\n", dsp);
  if (dsp->client) {
    // fprintf(stderr, "sdrkit_delete(%p) client %p\n", _sdrkit, dsp->client);
    jack_deactivate(dsp->client);
    // fprintf(stderr, "sdrkit_delete(%p) client deactivated\n", _sdrkit);
    jack_client_close(dsp->client);
    // fprintf(stderr, "sdrkit_delete(%p) client closed\n", _sdrkit);
  }
  if (dsp->command_delete) {
    dsp->command_delete(_sdrkit);
  }
  // fprintf(stderr, "sdrkit_delete(%p) command deleted\n", _sdrkit);
  if (dsp->port) {
    Tcl_Free((void *)dsp->port);
    // fprintf(stderr, "sdrkit_delete(%p) port freed\n", _sdrkit);
  }
  Tcl_Free((void *)dsp);
  // fprintf(stderr, "sdrkit_delete(%p) dsp freed\n", _sdrkit);
}

/* report jack status in strings */
#define stringify(x) #x

static void sdrkit_jack_status_report(Tcl_Interp *interp, jack_status_t status) {
  if (status & JackFailure) Tcl_AppendResult(interp, "; " stringify(JackFailure), NULL);
  if (status & JackInvalidOption) Tcl_AppendResult(interp, "; " stringify(JackInvalidOption), NULL);
  if (status & JackNameNotUnique) Tcl_AppendResult(interp, "; " stringify(JackNameNotUnique), NULL);
  if (status & JackServerStarted) Tcl_AppendResult(interp, "; " stringify(JackServerStarted), NULL);
  if (status & JackServerFailed) Tcl_AppendResult(interp, "; " stringify(JackServerFailed), NULL);
  if (status & JackServerError) Tcl_AppendResult(interp, "; " stringify(JackServerError), NULL);
  if (status & JackNoSuchClient) Tcl_AppendResult(interp, "; " stringify(JackNoSuchClient), NULL);
  if (status & JackLoadFailure) Tcl_AppendResult(interp, "; " stringify(JackLoadFailure), NULL);
  if (status & JackInitFailure) Tcl_AppendResult(interp, "; " stringify(JackInitFailure), NULL);
  if (status & JackShmFailure) Tcl_AppendResult(interp, "; " stringify(JackShmFailure), NULL);
  if (status & JackVersionError) Tcl_AppendResult(interp, "; " stringify(JackVersionError), NULL);
  if (status & JackBackendError) Tcl_AppendResult(interp, "; " stringify(JackBackendError), NULL);
  if (status & JackClientZombie) Tcl_AppendResult(interp, "; " stringify(JackClientZombie), NULL);
}  

/* find the jack server to open */
static const char * const sdrkit_find_server(int argc, Tcl_Obj* const *objv) {
  for (int i = 1; i < argc; i += 1) {
    // look for -server option
    if (strcmp(Tcl_GetString(objv[i]), "-server") == 0) {
      // look for next argument
      if (i+1 < argc)
	return Tcl_GetString(objv[i+1]);
      else
	return NULL;
    }
  }
  // look for environment specification
  if (getenv("JACK_DEFAULT_SERVER"))
    return getenv("JACK_DEFAULT_SERVER");
  // use the default
  return "default";
}

/* create a new dsp module factory */
static int sdrkit_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv,
		       const int n_inputs, const int n_outputs, const int n_midi_inputs, const int n_midi_outputs,
		       int (*command)(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv),
		       int (*process)(jack_nframes_t nframes, void *arg),
		       size_t data_size,
		       void *(*init)(void *arg),
		       void (*command_delete)(void *arg)) {
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s name", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  const char * const server_name = sdrkit_find_server(argc, objv);
  if (server_name == NULL) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("-server option missing server name"));
    return TCL_ERROR;
  }
  const char * const cmd_name = Tcl_GetString(objv[1]);
  const char * const client_name = strrchr(cmd_name, ':') ? strrchr(cmd_name, ':')+1 : cmd_name;
  // fprintf(stderr, "sdrkit_factory: cmd_name %s, client_name %s\n", cmd_name, client_name);
  jack_status_t status;
  jack_client_t *client = jack_client_open(client_name, JackServerName|JackUseExactName, &status, server_name);
  // fprintf(stderr, "sdrkit_factory: client %p\n", client);  
  if (client == NULL) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_client_open(%s, JackServerName|JackUseExactName, ..., %s) failed", client_name, server_name));
    sdrkit_jack_status_report(interp, status);
    return TCL_ERROR;
  }
  sdrkit_t *data = (sdrkit_t *)Tcl_Alloc(data_size);
  // fprintf(stderr, "sdrkit_factory: data %p\n", data);  
  if (data == NULL) {
    jack_client_close(client);
    Tcl_SetObjResult(interp, Tcl_NewStringObj("memory allocation failure", -1));
    return TCL_ERROR;
  }
  data->client = client;
  data->n_inputs = n_inputs;
  data->n_outputs = n_outputs;
  data->n_midi_inputs = n_midi_inputs;
  data->n_midi_outputs = n_midi_outputs;
  data->port = (jack_port_t **)Tcl_Alloc((n_inputs+n_outputs+n_midi_inputs+n_midi_outputs)*sizeof(jack_port_t *));
  data->command_delete = NULL;
  // fprintf(stderr, "sdrkit_factory: port %p\n", data->port);  
  if (data->port == NULL) {
    sdrkit_delete(data);
    Tcl_SetObjResult(interp, Tcl_NewStringObj("memory allocation failure", -1));
    return TCL_ERROR;
  }
  for (int i = 0; i < n_inputs; i++) {
    char buf[256];
    if (n_inputs > 2) {
      snprintf(buf, 256, "in_%d_%c", i/2, i&1 ? 'q' : 'i');
    } else {
      snprintf(buf, 256, "in_%c", i&1 ? 'q' : 'i');
    }
    data->port[i] = jack_port_register(client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsInput, 0);
  }
  for (int i = 0; i < n_outputs; i++) {
    char buf[256];
    if (n_outputs > 2) {
      snprintf(buf, 256, "out_%d_%c", i/2, i&1 ? 'q' : 'i');
    } else {
      snprintf(buf, 256, "out_%c", i&1 ? 'q' : 'i');
    }
    data->port[i+n_inputs] = jack_port_register(client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);
  }
  for (int i = 0; i < n_midi_inputs; i++) {
    char buf[256];
    if (n_midi_inputs > 1)
      snprintf(buf, 256, "midi_in_%d", i);
    else 
      snprintf(buf, 256, "midi_in");
    data->port[i+n_inputs+n_outputs] = jack_port_register(client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
  }
  for (int i = 0; i < n_midi_outputs; i++) {
    char buf[256];
    if (n_midi_inputs > 1)
      snprintf(buf, 256, "midi_out_%d", i);
    else 
      snprintf(buf, 256, "midi_out");
    data->port[i+n_midi_inputs+n_inputs+n_outputs] = jack_port_register(client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsOutput, 0);
  }
  // initialize the object data
  init((void *)data);
  data->command_delete = command_delete;
  // set generic callbacks
  jack_on_shutdown(client, sdrkit_delete, data);
  jack_set_process_callback(client, process, data);
  // create Tcl command
  Tcl_CreateObjCommand(interp, cmd_name, command, (ClientData)data, sdrkit_delete);
  // activate the client
  // fprintf(stderr, "sdrkit_factory: activate client\n");  
  status = (jack_status_t)jack_activate(client);
  if (status) {
    // fprintf(stderr, "sdrkit_factory: activate failed\n");  
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_activate(%s) failed: ", client_name));
    // this is just a guess, the header doesn't say it's so
    // jack_status_report(adaptp->interp, status);
    sdrkit_delete(data);
    return TCL_ERROR;
  }
  // fprintf(stderr, "sdrkit_factory: returning okay\n");
  Tcl_SetObjResult(interp, objv[1]);
  return TCL_OK;
}

static int sdrkit_init(Tcl_Interp *interp, const char *pkg, const char *pkg_version, const char *name, int (*factory)(ClientData, Tcl_Interp *, int, Tcl_Obj* const *)) {
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
  Tcl_PkgProvide(interp, pkg, pkg_version);
  Tcl_CreateObjCommand(interp, name, factory, NULL, NULL);
  return TCL_OK;
}

#endif
