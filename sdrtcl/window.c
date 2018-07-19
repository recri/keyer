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

#include "framework.h"		// shifted up to get window_mode_custom_option table
#include "../dspmath/dspmath.h"
#include "../dspmath/window.h"

/*
** create fft and filter windows.
*/
static int _get_window(Tcl_Interp *interp, const char *type_name, int *itype) {
  *itype = -1;
  for (int i = 0; window_mode_custom_option[i].name != NULL; i += 1)
    if (strcmp(window_mode_custom_option[i].name, type_name) == 0) {
      *itype = window_mode_custom_option[i].value;
      return TCL_OK;
    }
  Tcl_AppendResult(interp, "unknown window type, should be one of ", NULL);
  for (int i = 0; window_mode_custom_option[i].name != NULL; i += 1) {
    if (i > 0) {
      Tcl_AppendResult(interp, ", ", NULL);
      if (window_mode_custom_option[i+1].name == NULL)
	Tcl_AppendResult(interp, "or ", NULL);
    }
    Tcl_AppendResult(interp, window_mode_custom_option[i].name, NULL);
  }
  return TCL_ERROR;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // check for usage
  int itype = -1, size, itype2 = -1;
  if (argc != 3 && argc != 4) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s type ?type2 size?", Tcl_GetString(objv[0])));
  if (_get_window(interp, Tcl_GetString(objv[1]), &itype) != TCL_OK) return TCL_ERROR;
  if (argc == 3) {
    if (Tcl_GetIntFromObj(interp, objv[2], &size) != TCL_OK) return TCL_ERROR;
    itype2 = WINDOW_NONE;
  } else {
    if (_get_window(interp, Tcl_GetString(objv[2]), &itype2) != TCL_OK) return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[3], &size) != TCL_OK) return TCL_ERROR;
  }
  Tcl_Obj *result = Tcl_NewObj();
  float *window = (float *)Tcl_SetByteArrayLength(result, size*sizeof(float));
  window_make2(itype, itype2, size, window);
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Window_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::window", "1.0.0", "sdrtcl::window", _command);
}

