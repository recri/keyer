/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2019 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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

#include "../dspmath/dspmath.h"
#include "framework.h"
#include <jack/ringbuffer.h>

/*
** create a ringbuffer
*/
typedef struct {
} options_t;

typedef struct {
  framework_t fw;
  jack_ringbuffer_t *rb;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->rb = jack_ringbuffer_create(4096);
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->rb != NULL) {
    jack_ringbuffer_free(data->rb);
    data->rb = NULL;
  }
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  return TCL_OK;
}

static int _get_read_vector(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  jack_ringbuffer_data_t p[2];
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get-read-vector", Tcl_GetString(objv[0])));
  jack_ringbuffer_get_read_vector(data->rb, &p[0]);
  return fw_success_obj(interp, Tcl_NewByteArrayObj((unsigned char *)&p[0], sizeof(p)));
}
static int _get_write_vector(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  jack_ringbuffer_data_t p[2];
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get-write-vector", Tcl_GetString(objv[0])));
  jack_ringbuffer_get_write_vector(data->rb, &p[0]);
  return fw_success_obj(interp, Tcl_NewByteArrayObj((unsigned char *)&p[0], sizeof(p)));
}
static int _read(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  Tcl_Obj *result;
  unsigned char *p;
  int n;
  if (argc != 2 && argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s read ?count?", Tcl_GetString(objv[0])));
  if (argc == 3) {
    if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK)
      return TCL_ERROR;
  } else {
    n = jack_ringbuffer_read_space(data->rb);
  }
  result = Tcl_NewByteArrayObj(NULL, n);
  p = Tcl_GetByteArrayFromObj(result, NULL);
  if (jack_ringbuffer_read(data->rb, p, n) != n)
    return fw_error_obj(interp, Tcl_ObjPrintf("read error"));
  return fw_success_obj(interp, result);
}
static int _write(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  unsigned char *p;
  int n;
  if (argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s write data", Tcl_GetString(objv[0])));
  p = Tcl_GetByteArrayFromObj(objv[2], &n);
  if (jack_ringbuffer_write(data->rb, p, n) != n)
    return fw_error_obj(interp, Tcl_ObjPrintf("write error"));
  return TCL_OK;
}
static int _peek(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  Tcl_Obj *result;
  unsigned char *p;
  int n;
  if (argc != 2 && argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s peek ?count?", Tcl_GetString(objv[0])));
  if (argc == 3) {
    if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK)
      return TCL_ERROR;
  } else {
    n = jack_ringbuffer_read_space(data->rb);
  }
  result = Tcl_NewByteArrayObj(NULL, n);
  p = Tcl_GetByteArrayFromObj(result, NULL);
  if (jack_ringbuffer_peek(data->rb, p, n) != n)
    return fw_error_obj(interp, Tcl_ObjPrintf("read error"));
  return fw_success_obj(interp, result);
}
static int _read_advance(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  if (argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s read-advance count", Tcl_GetString(objv[0])));
  if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK)
    return TCL_ERROR;
  jack_ringbuffer_read_advance(data->rb, n);
  return TCL_OK;
}
static int _write_advance(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  if (argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s write-advance count", Tcl_GetString(objv[0])));
  if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK)
    return TCL_ERROR;
  jack_ringbuffer_write_advance(data->rb, n);
  return TCL_OK;
}
static int _read_space(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s read-space", Tcl_GetString(objv[0])));
  return fw_success_obj(interp, Tcl_NewIntObj(jack_ringbuffer_read_space(data->rb)));
}
static int _write_space(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s write-space", Tcl_GetString(objv[0])));
  return fw_success_obj(interp, Tcl_NewIntObj(jack_ringbuffer_write_space(data->rb)));
}
static int _reset(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s reset", Tcl_GetString(objv[0])));
  jack_ringbuffer_reset(data->rb);
  return TCL_OK;
}
static int _reset_size(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  if (argc != 3) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s reset-size size", Tcl_GetString(objv[0])));
  if (Tcl_GetIntFromObj(interp, objv[2], &n) != TCL_OK) return TCL_ERROR;
  jack_ringbuffer_reset_size(data->rb, n);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get-read-vector",  _get_read_vector,  "get readable space description" },
  { "get-write-vector", _get_write_vector, "get writable space description" },
  { "read",		_read,		    "read bytes" },
  { "write",		_write,             "write bytes" },
  { "peek",		_peek,		    "peek at bytes" },
  { "read-advance",     _read_advance,      "advance read pointer" },
  { "write-advance",    _write_advance,     "advace write pointer" },
  { "read-space",       _read_space,        "read space available" },
  { "write-space",      _write_space,       "write space available" },
  { "reset",		_reset,		    "reset read and write pointers (not thread safe)" },
  { "reset-size",	_reset_size,	    "reset size of ringbuffer (not thread safe)" },
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
  "/usr/include/jack/ringbuffer.h, a lockless ringbuffer"
};

// the adapter factory command
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Jack_ringbuffer_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::jack-ringbuffer", "1.0.0", "sdrtcl::jack-ringbuffer", _factory);
}

