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

#define FRAMEWORK_USES_JACK 0

#include "../sdrkit/dmath.h"
#include "../sdrkit/window.h"
#include "framework.h"

/*
** create a window module which generates
** fft and filter windows.
*/
typedef struct {
  Tcl_Obj *type;		/* one of the window types */
  int size;			/* window size in floats */
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  int itype;
  Tcl_Obj *window;		/* window as byte array */
} _t;

static void *_configure(_t *data) {
  char *type_name = Tcl_GetString(data->opts.type);
  int itype = -1;
  for (int i = 0; window_names[i] != NULL; i += 1)
    if (strcmp(window_names[i], type_name) == 0) {
      itype = i;
      break;
    }
  if (itype < 0) return "unknown window type";
  data->itype = itype;
  if (data->window != NULL) {
    Tcl_DecrRefCount(data->window);
  }
  data->window = Tcl_NewObj();
  Tcl_IncrRefCount(data->window);
  float *window = (float *)Tcl_SetByteArrayLength(data->window, data->opts.size*sizeof(float));
  window_make(data->itype, data->opts.size, window);
  return data;
}
static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void * e = _configure(data); if (e != data) return e;
  return arg;
}
static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->opts.type != NULL) Tcl_DecrRefCount(data->opts.type);
  data->opts.type = NULL;
  if (data->window != NULL) Tcl_DecrRefCount(data->window);
  data->window = NULL;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, data->window);
  return TCL_OK;
}
static int _types(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s types", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  Tcl_Obj *result = Tcl_NewObj();
  for (int i = 0; window_names[i] != NULL; i += 1)
    if (Tcl_ListObjAppendElement(interp, result, Tcl_NewStringObj(window_names[i], -1)) != TCL_OK)
      return TCL_ERROR;
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  if (data->opts.size != save.size || data->opts.type != save.type) {
    void *e = _configure(data); if (e != data) {
      data->opts = save;
      Tcl_SetResult(interp, e, TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-type", "type", "Type", "blackmanharris", fw_option_obj, 0, offsetof(_t, opts.type), "window type name" },
  { "-size", "size", "Size", "1024",	       fw_option_int, 0, offsetof(_t, opts.size), "window size" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "types", _types, "list the types of windows" },
  { "get",   _get,   "get the byte array that implements the window" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  NULL,				// process callback
  0, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a filter/fft window function component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Window_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::window", "1.0.0", "sdrkit::window", _factory);
}

