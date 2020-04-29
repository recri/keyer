/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
** access to builtin dict
*/

#define FRAMEWORK_USES_JACK 0
#define FRAMEWORK_USES_COMMAND 0
#define FRAMEWORK_USES_OPTIONS 0
#define FRAMEWORK_USES_SUBCOMMANDS 0

#include "framework.h"
#include "../dspmath/dspmath.h"
#include "../dspmath/morse_coding.h"

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 1) return fw_error_obj(interp, Tcl_ObjPrintf("usage %s", Tcl_GetString(objv[0])));
  return fw_success_obj(interp, Tcl_NewStringObj(morse_coding_dict_string, -1));
}

int DLLEXPORT Keyer_builtin_dict_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::keyer-builtin-dict", "1.0.0", "sdrtcl::keyer-builtin-dict", _factory);
}

