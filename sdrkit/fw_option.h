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
#ifndef FW_OPTION_H
#define FW_OPTION_H

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
    if (Tcl_GetIntFromObj(interp, val, &ival) != TCL_OK)
      return TCL_ERROR;
    *(int *)(clientData+entry->offset) = ival;
    return TCL_OK;
  }
  case fw_option_nframes: {
    long nval;
    if (Tcl_GetLongFromObj(interp, val, &nval) != TCL_OK)
      return TCL_ERROR;
    *(jack_nframes_t *)(clientData+entry->offset) = (jack_nframes_t)nval;
    return TCL_OK;
  }
  case fw_option_float: {
    double fval;
    if (Tcl_GetDoubleFromObj(interp, val, &fval) != TCL_OK)
      return TCL_ERROR;
    *(float *)(clientData+entry->offset) = fval;
    return TCL_OK;
  }
  case fw_option_char: {
    int clength;
    char *cval= Tcl_GetStringFromObj(val, &clength);
    if (clength != 1) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("character option value is longer than one character: \"%s\"", cval));
      return TCL_ERROR;
    }
    *(char *)(clientData+entry->offset) = *cval;
    return TCL_OK;
  }
  case fw_option_boolean: {
    int bval;
    if (Tcl_GetBooleanFromObj(interp, val, &bval) != TCL_OK)
      return TCL_ERROR;
    *(int *)(clientData+entry->offset) = bval;
    return TCL_OK;
  }
  case fw_option_obj: 
    Tcl_IncrRefCount(val);
    *(Tcl_Obj **)(clientData+entry->offset) = val;
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
  case fw_option_int:
    return Tcl_NewIntObj(*(int *)(clientData+entry->offset));
  case fw_option_nframes:
    return Tcl_NewLongObj(*(jack_nframes_t *)(clientData+entry->offset));
  case fw_option_float:
    return Tcl_NewDoubleObj(*(float *)(clientData+entry->offset));
  case fw_option_char:
    return Tcl_NewStringObj((char *)(clientData+entry->offset), 1);
  case fw_option_boolean:
    return Tcl_NewIntObj(*(int *)(clientData+entry->offset));
  case fw_option_obj:
    return *(Tcl_Obj **)(clientData+entry->offset);
  default:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("unimplemented option value type: %d", entry->type));
    return NULL;
  }
}

/*
** called by command create to process option arguments starting at objv[2].
*/
static int fw_option_create(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
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
    return fw_option_create(clientData, interp, argc, objv);
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

#endif
