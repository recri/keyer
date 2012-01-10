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
*/

#include <tcl.h>
#include <jack/jack.h>

#include "fw_options.h"

typedef struct {
  char *name;			/* subcommand name */
  int (*handler)(ClientData, Tcl_Interp *, int argc, Tcl_Obj* const *objv);
} fw_subcommand_table_t;

static int fw_subcommand_configure(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
}
static int fw_subcommand_cget(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
}
static int fw_subcommand_dispatch(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
}

#endif
