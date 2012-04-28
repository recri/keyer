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
#define FRAMEWORK_USES_COMMAND 0
#define FRAMEWORK_USES_OPTIONS 0
#define FRAMEWORK_USES_SUBCOMMANDS 0

#include "../sdrkit/dmath.h"
#include "../sdrkit/window.h"
#include "framework.h"

/*
** create fft and filter windows.
*/
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // check for usage
  if (argc != 3) return fw_error_str(interp, "usage: sdrkit::window type size");
  char *type_name = Tcl_GetString(objv[1]);
  int itype = -1;
  for (int i = 0; window_names[i] != NULL; i += 1)
    if (strcmp(window_names[i], type_name) == 0) {
      itype = i;
      break;
    }
  if (itype < 0) {
    Tcl_AppendResult(interp, "unknown window type, should be one of ", NULL);
    for (int i = 0; window_names[i] != NULL; i += 1) {
      if (i > 0) {
	Tcl_AppendResult(interp, ", ", NULL);
	if (window_names[i+1] == NULL)
	  Tcl_AppendResult(interp, "or ", NULL);
      }
      Tcl_AppendResult(interp, window_names[i], NULL);
    }
    return TCL_ERROR;
  }
  int size;
  if (Tcl_GetIntFromObj(interp, objv[2], &size) != TCL_OK) return TCL_ERROR;
  Tcl_Obj *result = Tcl_NewObj();
  float *window = (float *)Tcl_SetByteArrayLength(result, size*sizeof(float));
  window_make(itype, size, window);
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Window_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::window", "1.0.0", "sdrkit::window", _command);
}

