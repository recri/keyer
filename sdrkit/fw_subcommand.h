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
#ifndef FW_SUBCOMMAND_H
#define FW_SUBCOMMAND_H

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

#endif
