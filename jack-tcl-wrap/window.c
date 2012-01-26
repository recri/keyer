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

#include <math.h>
#include <complex.h>

#include "../sdrkit/window.h"

/*
** create a window module which generates
** fft and filter windows.
*/
typedef struct {
  Tcl_Obj *type;		/* one of the window types */
  int size;			/* size of window in floats */
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  int itype;
  Tcl_Obj *window;		/* window as byte array */
} _t;

static void *_update(_t *data) {
  float *
  if (data->window == NULL) {
    data->window = 
  return data;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  
  return arg;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.size != save.size || data->opts.window_type != save.window_type);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-type", "type", "Type", "blackmanharris", fw_option_obj, 0, offsetof(_t, opts.window_type), "window type name" },
  { "-size", "size", "Size", "1024",	       fw_option_int, 0, offsetof(_t, opts.size),        "window size" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "types", _types, "list the types of windows" }
  
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  NULL,				// process callback
  0, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a gain component"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Gain_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::gain", "1.0.0", "sdrkit::gain", _factory);
}

