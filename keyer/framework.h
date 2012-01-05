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
#ifndef FRAMEWORK_H
#define FRAMEWORK_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdio.h>
#include <string.h>
#if AS_BIN
#include <stdlib.h>
#include <signal.h>
#endif
#include <jack/jack.h>
#include <jack/midiport.h>
#if AS_TCL
#include <tcl.h>
#endif


#include "options.h"

#if AS_BIN
enum {
  require_midi_in = 1,
  require_midi_out = 2,
  require_out_i = 4,
  require_out_q = 8
};
#endif

typedef struct {
  options_t opts;
  jack_client_t *client;
  char n_inputs;
  char n_outputs;
  char n_midi_inputs;
  char n_midi_outputs;
  jack_port_t **port;
  void (*command_delete)(void *);
  int argc;
  char **argv;
  char *default_client_name;
  int (*process_callback)(jack_nframes_t nframes, void *arg);
  void (*receive_input_char)(char c, void *arg);
  char *commands;
} framework_t;

static jack_port_t *framework_port(void *p, int i) {
  return ((framework_t *)p)->port[i];
}
static jack_port_t *framework_input(void *p, int i) {
  return framework_port(p, i);
}
static jack_port_t *framework_output(void *p, int i) {
  return framework_port(p, i+((framework_t *)p)->n_inputs);
}
static jack_port_t *framework_midi_input(void *p, int i) {
  return framework_port(p, i+((framework_t *)p)->n_inputs+((framework_t *)p)->n_outputs);
}
static jack_port_t *framework_midi_output(void *p, int i) {
  return framework_port(p, i+((framework_t *)p)->n_inputs+((framework_t *)p)->n_outputs+((framework_t *)p)->n_midi_inputs);
}

/*
** The main framework for as an application:
** 1) Specify it's default jack client name.
** 2) Parse arguments
** 3) Open jack client
** 4) Set the sample rate and initialize client code
** 5) Set the jack callbacks
** 6) Register the jack ports
** 7) Activate the client
** 8) Install signal handler
** 9) Read input until done
** 10) Close the jack client
** 11) Exit.
**
** The differences between applications are:
** 1) jack client name
** 2) jack ports
** 3) initialization code
** 4) input reader beyond parsing commands
**
** As a Tcl plugin the framework would be:
** 1) Specify default jack client name.
** 2) Parse arguments (using -opt rather than --opt)
** 3) Open jack client
** 4) Set the sample rate and initialize client code
** 5) Set the jack callbacks
** 6) Register the jack ports
** 7) Activate the client
**
** The tcl plugin would receive command updates and input
** text through the tcl command, and would terminate the
** client through the same mechanism.
**
** So a framework would allow us to specify:
** 1) default client name
** 2) jack ports required: MIDI_IN|MIDI_OUT|AUDIO_OUT_I|AUDIO_OUT_Q
** 3?) initialization function pointer (might be autocalled).
** 4) jack process callback function pointer
*/

static int framework_jack_sample_rate_callback(jack_nframes_t nframes, void *arg) {
  framework_t *fp = (framework_t *)arg;
  options_set_sample_rate(&fp->opts, nframes);
  return 0;
}

static void framework_jack_shutdown_callback(void *arg) {
  exit(1);
}

#if AS_BIN
static framework_t *_kfp;
static void framework_signal_handler(int sig) {
  jack_client_close(_kfp->client);
  exit(0);
}

static void framework_main(void *arg, int argc, char **argv,
				 char *default_client_name,
				 const int n_inputs, const int n_outputs, const int n_midi_inputs, const int n_midi_outputs,
				 void (*init)(void *),
				 int (*process_callback)(jack_nframes_t nframes, void *arg),
				 void (*receive_input_char)(char c, void *)) {
  framework_t *kfp = (framework_t *)arg;
  kfp->argc = argc;
  kfp->argv = argv;
  kfp->default_client_name = default_client_name;
  kfp->process_callback = process_callback;
  kfp->receive_input_char = receive_input_char;
  strncpy(kfp->opts.client, kfp->default_client_name, sizeof(kfp->opts.client));
  options_parse_options(&kfp->opts, argc, argv);

  if((kfp->client = jack_client_open(kfp->opts.client, JackServerName, NULL, kfp->opts.server)) == 0) {
    fprintf(stderr, "JACK server not running?\n");
    exit(1);
  }

  jack_set_process_callback(kfp->client, kfp->process_callback, arg);
  jack_set_sample_rate_callback(kfp->client, framework_jack_sample_rate_callback, arg);
  jack_on_shutdown(kfp->client, framework_jack_shutdown_callback, arg);

  kfp->n_inputs = n_inputs;
  kfp->n_outputs = n_outputs;
  kfp->n_midi_inputs = n_midi_inputs;
  kfp->n_midi_outputs = n_midi_outputs;
  kfp->port = (jack_port_t **)calloc((n_inputs+n_outputs+n_midi_inputs+n_midi_outputs), sizeof(jack_port_t *));
  if (kfp->port == NULL) {
    fprintf(stderr, "memory allocation failure\n");
    exit(2);
  }
  for (int i = 0; i < n_inputs; i++) {
    char buf[256];
    if (n_inputs > 2) {
      snprintf(buf, 256, "in_%d_%c", i/2, i&1 ? 'q' : 'i');
    } else {
      snprintf(buf, 256, "in_%c", i&1 ? 'q' : 'i');
    }
    kfp->port[i] = jack_port_register(kfp->client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsInput, 0);
  }
  for (int i = 0; i < n_outputs; i++) {
    char buf[256];
    if (n_outputs > 2) {
      snprintf(buf, 256, "out_%d_%c", i/2, i&1 ? 'q' : 'i');
    } else {
      snprintf(buf, 256, "out_%c", i&1 ? 'q' : 'i');
    }
    kfp->port[i+n_inputs] = jack_port_register(kfp->client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);
  }
  for (int i = 0; i < n_midi_inputs; i++) {
    char buf[256];
    if (n_midi_inputs > 1)
      snprintf(buf, 256, "midi_in_%d", i);
    else 
      snprintf(buf, 256, "midi_in");
    kfp->port[i+n_inputs+n_outputs] = jack_port_register(kfp->client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
  }
  for (int i = 0; i < n_midi_outputs; i++) {
    char buf[256];
    if (n_midi_inputs > 1)
      snprintf(buf, 256, "midi_out_%d", i);
    else 
      snprintf(buf, 256, "midi_out");
    kfp->port[i+n_midi_inputs+n_inputs+n_outputs] = jack_port_register(kfp->client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsOutput, 0);
  }

  options_set_sample_rate(&kfp->opts, jack_get_sample_rate(kfp->client));
  if (init != NULL) init(arg);

  if (jack_activate (kfp->client)) {
    fprintf(stderr, "cannot activate client");
    exit(1);
  }

  /* install a signal handler to properly quits jack client */
  _kfp = kfp;
  signal(SIGQUIT, framework_signal_handler);
  signal(SIGTERM, framework_signal_handler);
  signal(SIGHUP, framework_signal_handler);
  signal(SIGINT, framework_signal_handler);

  /* run until interrupted */
  /* while read bytes, queue for transmission */
  char c;
  while ((c = getchar()) != EOF) {
    if (c == '<') {
      /* command escape */
      char buff[128];
      int i = 0;
      while ((c = getchar()) != EOF && c != '>' && i < sizeof(buff)-1)
	buff[i++] = c;
      buff[i] = 0;
      options_parse_command(&kfp->opts, buff);
    } else if (kfp->receive_input_char) {
      kfp->receive_input_char(c, arg);
    }
  }

  jack_client_close(kfp->client);
  exit(0);
}
#endif

#if AS_TCL
static int framework_usage(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s (%s) ...\n", Tcl_GetString(objv[0]), fp->commands));
  return TCL_ERROR;
}

/* implement a Tcl command for config or cget */
static int framework_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  if (argc < 2)
    return framework_usage(clientData, interp, argc, objv);
  char *cmd = Tcl_GetString(objv[1]);
  if (strcmp(cmd, "config") == 0) {
    return options_parse_config(&fp->opts, interp, argc, objv);
  } else if (strcmp(cmd, "cget") == 0 && argc == 3) {
    return options_parse_cget(&fp->opts, interp, argc, objv);
  } else if (strcmp(cmd, "cdoc") == 0 && argc == 3) {
    return options_parse_cdoc(&fp->opts, interp, argc, objv);
  } else
    return framework_usage(clientData, interp, argc, objv);
  return TCL_OK;
}

/* delete a dsp module cleanly */
static void framework_delete(void *arg) {
  framework_t *dsp = (framework_t *)arg;
  // fprintf(stderr, "framework_delete(%p)\n", dsp);
  if (dsp->client) {
    // fprintf(stderr, "framework_delete(%p) client %p\n", _sdrkit, dsp->client);
    jack_deactivate(dsp->client);
    // fprintf(stderr, "framework_delete(%p) client deactivated\n", _sdrkit);
    jack_client_close(dsp->client);
    // fprintf(stderr, "framework_delete(%p) client closed\n", _sdrkit);
  }
  if (dsp->command_delete) {
    dsp->command_delete(arg);
  }
  // fprintf(stderr, "framework_delete(%p) command deleted\n", _sdrkit);
  if (dsp->port) {
    Tcl_Free((char *)(void *)dsp->port);
    // fprintf(stderr, "framework_delete(%p) port freed\n", _sdrkit);
  }
  Tcl_Free((char *)(void *)dsp);
  // fprintf(stderr, "framework_delete(%p) dsp freed\n", _sdrkit);
}

/* report jack status in strings */
#define stringify(x) #x

static void framework_jack_status_report(Tcl_Interp *interp, jack_status_t status) {
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

/* keyer module factory command */
/* usage: keyer_module_type_name command_name [options] */
static int framework_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv,
			     const int n_inputs, const int n_outputs, const int n_midi_inputs, const int n_midi_outputs,
			     int (*command)(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv),
			     int (*process)(jack_nframes_t nframes, void *arg),
			     size_t data_size,
			     void (*init)(void *arg),
			     void (*command_delete)(void *arg),
			     char *commands) {
  if (argc < 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s name [-option value ...]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  framework_t *data = (framework_t *)Tcl_Alloc(data_size);
  memset(data, 0, data_size);
  // fprintf(stderr, "framework_factory: data %p\n", data);  
  if (data == NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("memory allocation failure", -1));
    return TCL_ERROR;
  }
  if (options_parse_options(&data->opts, interp, argc, objv) != TCL_OK) {
    Tcl_Free((char *)data);
    return TCL_ERROR;
  }
  // fprintf(stderr, "framework_factory: cmd_name %s, client_name %s\n", cmd_name, client_name);
  jack_status_t status;
  jack_client_t *client = jack_client_open(data->opts.client, (jack_options_t)(JackServerName|JackUseExactName), &status, data->opts.server);
  // fprintf(stderr, "framework_factory: client %p\n", client);  
  if (client == NULL) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_client_open(%s, JackServerName|JackUseExactName, ..., %s) failed",
					   data->opts.client, data->opts.server));
    framework_jack_status_report(interp, status);
    return TCL_ERROR;
  }
  data->client = client;
  data->n_inputs = n_inputs;
  data->n_outputs = n_outputs;
  data->n_midi_inputs = n_midi_inputs;
  data->n_midi_outputs = n_midi_outputs;
  data->port = (jack_port_t **)Tcl_Alloc((n_inputs+n_outputs+n_midi_inputs+n_midi_outputs)*sizeof(jack_port_t *));
  memset(data->port, 0, (n_inputs+n_outputs+n_midi_inputs+n_midi_outputs)*sizeof(jack_port_t *));
  data->command_delete = NULL;
  data->commands = commands;
  // fprintf(stderr, "framework_factory: port %p\n", data->port);  
  if (data->port == NULL) {
    framework_delete(data);
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
  // set the sample rate
  options_set_sample_rate(&data->opts, jack_get_sample_rate(data->client));
  // initialize the object data
  init((void *)data);
  data->command_delete = command_delete;
  // set generic callbacks
  jack_on_shutdown(client, framework_delete, data);
  jack_set_process_callback(client, process, data);
  // create Tcl command
  Tcl_CreateObjCommand(interp, Tcl_GetString(objv[1]), command, (ClientData)data, framework_delete);
  // activate the client
  // fprintf(stderr, "framework_factory: activate client\n");  
  status = (jack_status_t)jack_activate(client);
  if (status) {
    // fprintf(stderr, "framework_factory: activate failed\n");  
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_activate(%s) failed: ", data->opts.client));
    // this is just a guess, the header doesn't say it's so
    // jack_status_report(adaptp->interp, status);
    framework_delete(data);
    return TCL_ERROR;
  }
  // fprintf(stderr, "framework_factory: returning okay\n");
  Tcl_SetObjResult(interp, objv[1]);
  return TCL_OK;
}

static int framework_init(Tcl_Interp *interp, const char *pkg, const char *pkg_version, const char *name, int (*factory)(ClientData, Tcl_Interp *, int, Tcl_Obj* const *)) {
  // tcl stubs and tk stubs are needed for dynamic loading,
  // you must have this set as a compiler option
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, TCL_VERSION, 1) == NULL) {
    Tcl_SetResult(interp, (char *)"Tcl_InitStubs failed", TCL_STATIC);
    return TCL_ERROR;
  }
#endif
#ifdef USE_TK_STUBS
  if (Tk_InitStubs(interp, TCL_VERSION, 1) == NULL) {
    Tcl_SetResult(interp, (char *)"Tk_InitStubs failed",TCL_STATIC);
    return TCL_ERROR;
  }
#endif
  Tcl_PkgProvide(interp, pkg, pkg_version);
  Tcl_CreateObjCommand(interp, name, factory, NULL, NULL);
  return TCL_OK;
}

#endif
#ifdef __cplusplus
}
#endif

#endif
