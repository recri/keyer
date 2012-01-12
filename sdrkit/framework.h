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

/*
** the framework provides the glue for creating Tcl commands,
** cleaning up after them when they're deleted,
** processing options,
** and parsing sub-command ensembles.
*/

/*
** needs some way to indicate that -server and -client are not
** available after command creation.
** needs some way to indicate that live options have been modified.
*/

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <jack/jack.h>
#include <jack/midiport.h>
#include <tcl.h>

/*
** option definitions
*/
typedef enum {
  fw_option_none,
  fw_option_int,
  fw_option_nframes,		/* jack_nframes_t */
  fw_option_float,
  fw_option_char,
  fw_option_boolean,
  fw_option_obj,		/* Tcl_Obj * */
} fw_option_type_t;

typedef struct {
  const char *name;			/* option name */
  const char *db_name;			/* option database name */
  const char *class_name;		/* option class name */
  const char *default_value;		/* option default value */
  const fw_option_type_t type;		/* option type */
  const size_t offset;			/* offset in clientData */
  const char *doc_string;		/* option documentation string */
} fw_option_table_t;

/*
** subcommand definitions
*/

typedef struct {
  const char *name;			/* subcommand name */
  int (*handler)(ClientData, Tcl_Interp *, int argc, Tcl_Obj* const *objv);
} fw_subcommand_table_t;

/*
** the framework client declares its own
** client data as a structure which contains
** this as the first element.
**
** the void *arg passed by Jack points to this.
**
** the ClientData clientData passed by Tcl points to this.
*/
typedef struct {
  const fw_option_table_t *options;
  const fw_subcommand_table_t *subcommands;
  void *(*init)(void *);
  int (*command)(ClientData, Tcl_Interp *, int, Tcl_Obj* const *);
  void (*cdelete)(void *);
  int (*sample_rate)(jack_nframes_t, void *);
  int (*process)(jack_nframes_t, void *);
  char n_inputs;
  char n_outputs;
  char n_midi_inputs;
  char n_midi_outputs;
  Tcl_Obj *class_name;
  Tcl_Obj *command_name;
  Tcl_Obj *server_name;
  Tcl_Obj *client_name;
  Tcl_Obj *subcommands_string;
  jack_client_t *client;
  jack_port_t **port;
} framework_t;

/*
** provide common option processing command creation, configure, and cget.
**
** allows commands to simply tabulate their options in an option_t array
** and get them handled in a consistent manner.
*/


static int fw_option_lookup(char *string, const fw_option_table_t *table) {
  for (int i = 0; table[i].name != NULL; i += 1)
    if (strcmp(table[i].name, string) == 0)
      return i;
  return -1;
}

static int fw_option_unrecognized_option_name(Tcl_Interp *interp, char *option) {
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("\"%s\" is not a valid option name ", option));
  return TCL_ERROR;
}

static int fw_option_wrong_number_of_arguments(Tcl_Interp *interp) {
  Tcl_SetObjResult(interp, Tcl_NewStringObj("invalid option list: each option should have a value", -1));
  return TCL_ERROR;
}

static int fw_option_set_option_value(ClientData clientData, Tcl_Interp *interp, Tcl_Obj *val, const fw_option_table_t *entry) {
  switch (entry->type) {
  case fw_option_int: {
    int ival;
    if (Tcl_GetIntFromObj(interp, val, &ival) != TCL_OK) return TCL_ERROR;
    *(int *)((char *)clientData+entry->offset) = ival;
    return TCL_OK;
  }
  case fw_option_nframes: {
    long nval;
    if (Tcl_GetLongFromObj(interp, val, &nval) != TCL_OK) return TCL_ERROR;
    *(jack_nframes_t *)((char *)clientData+entry->offset) = (jack_nframes_t)nval;
    return TCL_OK;
  }
  case fw_option_float: {
    double fval;
    if (Tcl_GetDoubleFromObj(interp, val, &fval) != TCL_OK) return TCL_ERROR;
    *(float *)((char *)clientData+entry->offset) = fval;
    return TCL_OK;
  }
  case fw_option_char: {
    int clength;
    char *cval= Tcl_GetStringFromObj(val, &clength);
    if (clength != 1) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("character option value is longer than one character: \"%s\"", cval));
      return TCL_ERROR;
    }
    *(char *)((char *)clientData+entry->offset) = *cval;
    return TCL_OK;
  }
  case fw_option_boolean: {
    int bval;
    if (Tcl_GetBooleanFromObj(interp, val, &bval) != TCL_OK) return TCL_ERROR;
    *(int *)((char *)clientData+entry->offset) = bval;
    return TCL_OK;
  }
  case fw_option_obj: 
    Tcl_IncrRefCount(val);
    *(Tcl_Obj **)((char *)clientData+entry->offset) = val;
    return TCL_OK;
  default:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("unimplemented option value type: %d", entry->type));
    return TCL_ERROR;
  }
}

/*
**
*/
static Tcl_Obj *fw_option_get_value_obj(ClientData clientData, Tcl_Interp *interp, const fw_option_table_t *entry) {
  switch (entry->type) {
  case fw_option_int:     return Tcl_NewIntObj(*(int *)((char *)clientData+entry->offset));
  case fw_option_nframes: return Tcl_NewLongObj(*(jack_nframes_t *)((char *)clientData+entry->offset));
  case fw_option_float:   return Tcl_NewDoubleObj(*(float *)((char *)clientData+entry->offset));
  case fw_option_char:    return Tcl_NewStringObj((char *)((char *)clientData+entry->offset), 1);
  case fw_option_boolean: return Tcl_NewIntObj(*(int *)((char *)clientData+entry->offset));
  case fw_option_obj:     return *(Tcl_Obj **)((char *)clientData+entry->offset);
  default:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("unimplemented option value type: %d", entry->type));
    return NULL;
  }
}

/*
** called by fw_option_create or fw_option_configure
*/
static int fw_option_collect(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  const fw_option_table_t *table = fp->options;
  if ((argc & 1) != 0) return fw_option_wrong_number_of_arguments(interp);
  for (int i = 2; i < argc; i += 2) {
    int j = fw_option_lookup(Tcl_GetString(objv[i]), table);
    if (j < 0) return fw_option_unrecognized_option_name(interp, Tcl_GetString(objv[i]));
    if (fw_option_set_option_value(clientData, interp, objv[i+1], table+j) != TCL_OK) return TCL_ERROR;
  }
  return TCL_OK;
}

/*
** called by command create to process option arguments starting at objv[2].
*/
static int fw_option_create(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // but first we install default values
  framework_t *fp = (framework_t *)clientData;
  const fw_option_table_t *table = fp->options;
  for (int i = 0; table[i].name != NULL; i += 1) {
    if (table[i].default_value != NULL) {
      if (fw_option_set_option_value(clientData, interp, Tcl_NewStringObj(table[i].default_value,-1), table+i) != TCL_OK) {
	return TCL_ERROR;
      }
    }
  }
  return fw_option_collect(clientData, interp, argc, objv);
}

/*
** called by configure subcommand to process option arguments starting at objv[2]
*/
static int fw_option_configure(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  const fw_option_table_t *table = fp->options;
  if (argc == 2) {
    // dump configuration
    Tcl_Obj *result = Tcl_NewObj();
    for (int i = 0; table[i].name != NULL; i += 1) {
      // fprintf(stderr, "configure processing for %s\n", table[i].name);
      Tcl_Obj *entry[] = {
	Tcl_NewStringObj(table[i].name, -1),
	Tcl_NewStringObj(table[i].db_name, -1),
	Tcl_NewStringObj(table[i].class_name, -1),
	Tcl_NewStringObj(table[i].default_value, -1),
	fw_option_get_value_obj(clientData, interp, table+i)
      };
      if (entry[4] == NULL) {
	// fprintf(stderr, "no value for %s???\n", table[i].name);
	return TCL_ERROR;
      }
      if (Tcl_ListObjAppendElement(interp, result, Tcl_NewListObj(5, entry)) != TCL_OK) {
	// fprintf(stderr, "cannot append element to result for %s???\n", table[i].name);
	return TCL_ERROR;
      }
    }
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
  } else {
    // the caller had better be prepared to restore clientData on error
    return fw_option_collect(clientData, interp, argc, objv);
  }
}

/*
** called by cget subcommand to process option arguments starting at objv[2]
*/
static int fw_option_cget(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  const fw_option_table_t *table = fp->options;
  if (argc != 3) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s cget option", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  int j = fw_option_lookup(Tcl_GetString(objv[2]), table);
  if (j < 0) return fw_option_unrecognized_option_name(interp, Tcl_GetString(objv[2]));
  Tcl_Obj *result = fw_option_get_value_obj(clientData, interp, table+j);
  if (result == NULL)
    return TCL_ERROR;
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}

/*
** called by cdoc subcommand to process option arguments starting at objv[2]
*/
static int fw_option_cdoc(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  const fw_option_table_t *table = fp->options;
  if (argc != 3) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s cdoc option", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  int j = fw_option_lookup(Tcl_GetString(objv[2]), table);
  if (j < 0) return fw_option_unrecognized_option_name(interp, Tcl_GetString(objv[2]));
  Tcl_SetObjResult(interp, Tcl_NewStringObj(table[j].doc_string, -1));
  return TCL_OK;
}

/*
** provide common subcommand processing
**
** allows commands to hand off command implementation
** for configure, cget, and cdoc to common option processor
** while specifying their own implementations for everything else
*/

static char *fw_subcommand_subcommands(ClientData clientData) {
  framework_t *fp = (framework_t *)clientData;
  if (fp->subcommands_string == NULL) {
    const fw_subcommand_table_t *table = fp->subcommands;
    fp->subcommands_string = Tcl_NewObj();
    Tcl_IncrRefCount(fp->subcommands_string);
    for (int i = 0; table[i].name != NULL; i += 1) {
      if (i != 0) {
	Tcl_AppendToObj(fp->subcommands_string, ", ", 2);
	if (table[i+1].name == NULL)
	  Tcl_AppendToObj(fp->subcommands_string, "or ", 3);
      }
      Tcl_AppendToObj(fp->subcommands_string, table[i].name, -1);
    }
  }
  return Tcl_GetString(fp->subcommands_string);
}

static int fw_subcommand_configure(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return fw_option_configure(clientData, interp, argc, objv);
}
static int fw_subcommand_cget(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return fw_option_cget(clientData, interp, argc, objv);
}
static int fw_subcommand_cdoc(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return fw_option_cdoc(clientData, interp, argc, objv);
}
static int fw_subcommand_dispatch(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  framework_t *fp = (framework_t *)clientData;
  // fprintf(stderr, "fw_subcommand_dispatch(%lx, %lx, %d, %lx)\n", (long)clientData, (long)interp, argc, (long)objv);
  const fw_subcommand_table_t *table = fp->subcommands;
  if (argc < 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s subcommand [ ... ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  char *subcmd = Tcl_GetString(objv[1]);
  for (int i = 0; table[i].name != NULL; i += 1)
    if (strcmp(subcmd, table[i].name) == 0)
      return table[i].handler(clientData, interp, argc, objv);
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("unrecognized subcommand \"%s\", should one of %s", subcmd, fw_subcommand_subcommands(clientData)));
  return TCL_ERROR;
}

/*
** framework utilities
*/
static jack_port_t *framework_port(void *p, int i) { return ((framework_t *)p)->port[i]; }
static jack_port_t *framework_input(void *p, int i) { return framework_port(p, i); }
static jack_port_t *framework_output(void *p, int i) { return framework_port(p, i+((framework_t *)p)->n_inputs); }
static jack_port_t *framework_midi_input(void *p, int i) { return framework_port(p, i+((framework_t *)p)->n_inputs+((framework_t *)p)->n_outputs); }
static jack_port_t *framework_midi_output(void *p, int i) { return framework_port(p, i+((framework_t *)p)->n_inputs+((framework_t *)p)->n_outputs+((framework_t *)p)->n_midi_inputs); }

static int sdrkit_sample_rate(void *arg) {
  return (int)jack_get_sample_rate(((framework_t *)arg)->client);
}

static jack_nframes_t sdrkit_buffer_size(void *arg) {
  return jack_get_buffer_size(((framework_t *)arg)->client);
}

static char *sdrkit_client_name(void *arg) {
  return jack_get_client_name(((framework_t *)arg)->client);
}

/* use this one from outside the process_callback */
static jack_nframes_t sdrkit_frame_time(void *arg) {
  return jack_frame_time(((framework_t *)arg)->client);
}

/* use this one inside the process_callback, for the first frame in the callback */
static jack_nframes_t sdrkit_last_frame_time(void *arg) {
  return jack_last_frame_time(((framework_t *)arg)->client);
}

/* translates frames to microseconds */
static jack_time_t sdrkit_frames_to_time(void *arg, jack_nframes_t frames) {
  return jack_frames_to_time(((framework_t *)arg)->client, frames);
}

/* translates microseconds to frames */
static jack_nframes_t sdrkit_time_to_frames(void *arg, jack_time_t time) {
  return jack_time_to_frames(((framework_t *)arg)->client, time);
}

/* get the jack time base */
static jack_time_t sdrkit_get_time() {
  return jack_get_time();
}

/* implement a Tcl subcommand */
static int framework_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return fw_subcommand_dispatch(clientData, interp, argc, objv);
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
  if (dsp->cdelete) {
    dsp->cdelete(arg);
  }
  // fprintf(stderr, "framework_delete(%p) command deleted\n", _sdrkit);
  if (dsp->port) {
    Tcl_Free((char *)(void *)dsp->port);
    // fprintf(stderr, "framework_delete(%p) port freed\n", _sdrkit);
  }

  if (dsp->class_name != NULL) Tcl_DecrRefCount(dsp->class_name);
  if (dsp->command_name != NULL) Tcl_DecrRefCount(dsp->command_name);
  if (dsp->server_name != NULL) Tcl_DecrRefCount(dsp->server_name);
  if (dsp->client_name != NULL) Tcl_DecrRefCount(dsp->client_name);
  if (dsp->subcommands_string != NULL) Tcl_DecrRefCount(dsp->subcommands_string);

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

static void framework_dump_template(const framework_t *atemplate) {
  fprintf(stderr, "template %lx\n", (long)atemplate);
  fprintf(stderr, "options %lx\n", (long)atemplate->options);
  for (int i = 0; atemplate->options[i].name != NULL; i += 1) fprintf(stderr, "  %d %s\n", i, atemplate->options[i].name);
  fprintf(stderr, "subcommands %lx\n", (long)atemplate->subcommands);
  for (int i = 0; atemplate->subcommands[i].name != NULL; i += 1) fprintf(stderr, "  %d %s\n", i, atemplate->subcommands[i].name);  
}

/* keyer module factory command */
/* usage: keyer_module_type_name command_name [options] */
static int framework_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv, const framework_t *atemplate, size_t data_size) {

  // test for insufficient arguments
  if (argc < 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s name [option value ...]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  // framework_dump_template(template);
  // check for some sanity
  if (atemplate->command == NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("command pointer?", -1));
    return TCL_ERROR;
  }
  if (atemplate->n_inputs+atemplate->n_outputs+atemplate->n_midi_inputs+atemplate->n_midi_outputs != 0 && atemplate->process == NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("jack ports but no jack process callback?", -1));
    return TCL_ERROR;
  }
  if (atemplate->n_inputs+atemplate->n_outputs+atemplate->n_midi_inputs+atemplate->n_midi_outputs == 0 && atemplate->process != NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("no jack ports for jack process callback?", -1));
    return TCL_ERROR;
  }

  // get class and command name
  char *class_name = Tcl_GetString(objv[0]);
  char *command_name = Tcl_GetString(objv[1]);

  // allocate command data
  framework_t *data = (framework_t *)Tcl_Alloc(data_size);
  if (data == NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("memory allocation afailure", -1));
    return TCL_ERROR;
  }

  // initialize command data
  memset(data, 0, data_size);
  memcpy(data, atemplate, sizeof(framework_t));
  data->cdelete = NULL;		// deferred until after data->init is called
  data->class_name = objv[0];
  Tcl_IncrRefCount(data->class_name);
  data->command_name = objv[1];
  Tcl_IncrRefCount(data->command_name);
  // fprintf(stderr, "%s data->command %lx, atemplate->command %lx\n", command_name, (long)data->command, (long)atemplate->command);

  // parse command line options
  if (fw_option_create(data, interp, argc, objv) != TCL_OK) {
    framework_delete(data);
    return TCL_ERROR;
  }

  // get jack server and client names
  char *server_name = data->server_name != NULL ? Tcl_GetString(data->server_name) :
    getenv("JACK_DEFAULT_SERVER") != NULL ? getenv("JACK_DEFAULT_SERVER") : (char *)"default";
  char *client_name = data->client_name != NULL ? Tcl_GetString(data->client_name) : command_name;

  // remove namespaces from client name
  if (strrchr(client_name, ':') != NULL) {
    client_name = strrchr(client_name, ':')+1;
    if (data->client_name != NULL) {
      Tcl_DecrRefCount(data->client_name);
      data->client_name = NULL;
    }
  }
  // fprintf(stderr, "framework_factory: cmd_name %s, client_name %s\n", cmd_name, client_name);

  if (data->server_name == NULL) {
    data->server_name = Tcl_NewStringObj(server_name, -1);
    Tcl_IncrRefCount(data->server_name);
  }
  if (data->client_name == NULL) {
    data->client_name = Tcl_NewStringObj(client_name, -1);
    Tcl_IncrRefCount(data->client_name);
  }

  // create jack client
  jack_status_t status;
  data->client = jack_client_open(client_name, (jack_options_t)(JackServerName|JackUseExactName), &status, server_name);
  // fprintf(stderr, "framework_factory: client %p\n", client);  
  if (data->client == NULL) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_client_open(%s, JackServerName|JackUseExactName, ..., %s) failed", client_name, server_name));
    framework_jack_status_report(interp, status);
    framework_delete(data);
    return TCL_ERROR;
  }

  // create jack ports
  int n = data->n_inputs+data->n_outputs+data->n_midi_inputs+data->n_midi_outputs;
  if (n > 0) {
    data->port = (jack_port_t **)Tcl_Alloc(n*sizeof(jack_port_t *));
    memset(data->port, 0, n*sizeof(jack_port_t *));
    // fprintf(stderr, "framework_factory: port %p\n", data->port);  
    if (data->port == NULL) {
      framework_delete(data);
      Tcl_SetObjResult(interp, Tcl_NewStringObj("memory allocation failure", -1));
      return TCL_ERROR;
    }
    char buf[256];
    for (int i = 0; i < data->n_inputs; i++) {
      if (data->n_inputs > 2) snprintf(buf, sizeof(buf), "in_%d_%c", i/2, i&1 ? 'q' : 'i');
      else snprintf(buf, sizeof(buf), "in_%c", i&1 ? 'q' : 'i');
      data->port[i] = jack_port_register(data->client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsInput, 0);
    }
    for (int i = 0; i < data->n_outputs; i++) {
      if (data->n_outputs > 2) snprintf(buf, sizeof(buf), "out_%d_%c", i/2, i&1 ? 'q' : 'i');
      else snprintf(buf, sizeof(buf), "out_%c", i&1 ? 'q' : 'i');
      data->port[i+data->n_inputs] = jack_port_register(data->client, buf, JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);
    }
    for (int i = 0; i < data->n_midi_inputs; i++) {
      if (data->n_midi_inputs > 1) snprintf(buf, sizeof(buf), "midi_in_%d", i);
      else snprintf(buf, sizeof(buf), "midi_in");
      data->port[i+data->n_inputs+data->n_outputs] = jack_port_register(data->client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
    }
    for (int i = 0; i < data->n_midi_outputs; i++) {
      if (data->n_midi_inputs > 1) snprintf(buf, sizeof(buf), "midi_out_%d", i);
      else snprintf(buf, sizeof(buf), "midi_out");
      data->port[i+data->n_midi_inputs+data->n_inputs+data->n_outputs] = jack_port_register(data->client, buf, JACK_DEFAULT_MIDI_TYPE, JackPortIsOutput, 0);
    }
  }

  // finish initialization the object data
  // returns data pointer on success, error string on failure
  // failure does not leave command specific stuff to be cleaned up
  if (data->init != NULL) {
    void *p = atemplate->init((void *)data);
    if (p != data) {
      // initialization failed
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("init of \"%s\", a \"%s\" command, failed: \"%s\"", command_name, class_name, (char *)p));
      framework_delete(data);
      return TCL_ERROR;
    }
  }
  data->cdelete = atemplate->cdelete;

  // create server_name, client_name, class_name, and command_name objects

  // set callbacks
  jack_on_shutdown(data->client, framework_delete, data);
  if (data->process) jack_set_process_callback(data->client, data->process, data);
  if (data->sample_rate) jack_set_sample_rate_callback(data->client, data->sample_rate, data);
  // if (data->buffer_size) jack_set_buffer_size_callback(data->client, data->buffer_size, data);
  // if (data->xrun) jack_set_xrun_callback(data->client, data->xrun, data);
  // client registration
  // port registration
  // graph reordering
  // port connect

  // create Tcl command
  // fprintf(stderr, "create command %s at %lx\n", command_name, (long)data->command);
  Tcl_CreateObjCommand(interp, command_name, data->command, (ClientData)data, framework_delete);

  // activate the client
  // fprintf(stderr, "framework_factory: activate client\n");  
  if (data->process) {
    status = (jack_status_t)jack_activate(data->client);
    if (status) {
      // fprintf(stderr, "framework_factory: activate failed\n");  
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("jack_activate(%s) failed: ", client_name));
      // this is just a guess, the header doesn't say it's so
      // jack_status_report(adaptp->interp, status);
      framework_delete(data);
      return TCL_ERROR;
    }
  }
  // fprintf(stderr, "framework_factory: returning okay\n");
  Tcl_SetObjResult(interp, objv[1]);
  return TCL_OK;
}

//
// framework_init - initializes a loadable tcl/tk module
// and installs a single factory command which creates
// instances of the command type.
//
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
