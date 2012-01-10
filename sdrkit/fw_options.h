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
#ifndef OPTIONS_H
#define OPTIONS_H

/*
** provide common option processing command creation, configure, and cget.
**
** allows commands to simply tabulate their options in an option_t array
** and get them handled in a consistent manner.
*/

#include <tcl.h>
#include <jack/jack.h>

typedef enum {
  options_int,
  options_nframes,
  options_float,
  options_char,
  options_boolean,
  options_string,
} option_type_t;

typedef union {
  int int_value;
  jack_nframes_t nframes_value;
  float float_value;
  char char_value;
  int boolean_value;
  char *string_value;
} option_value_t

typedef struct {
  char *name;			/* option name */
  option_type_t type;		/* option type */
  option_value_t value;		/* option value */
  option_value_t default_value;	/* option default value */
  size_t offset;		/* offset in clientData */
} option_table_t;

typedef enum {
  option_call_create,
  option_call_configure,
  option_call_cget
} option_call_type;

typedef struct {
  ClientData clientData;
  Tcl_Interp *interp;
  int argc;
  Tcl_Obj* const *objv;
  option_call_type_t type;
  option_table_t *table;
  int first_option_arg;
  ClientData saved_clientData;
} option_call_t;

static int options_lookup(option_table_t *table, char *string) {
  
}
/*
** called when a command create reaches the first option argument
** or when a configure subcommand is recognized
** or when a cget subcommand is recognized.
** the parameters are wrapped into an option_call_t and passed here.
*/
static int options_handle(option_call_t *call) {
  
  if (call
  
}

/*
** call with argc and objv
#endif
