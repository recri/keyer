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

#define FRAMEWORK_USES_JACK 0
#define _POSIX_C_SOURCE 1
#include <signal.h>
#include <stdint.h>
#include <jack/control.h>

#include "framework.h"

/*
** The proper use of this extension requires a thread per server
** started because of the jackctl_wait_signals(signals) that
** occurs in the middle of this sequence:

	server = jackctl_server_create(NULL, NULL);
	// set server parameters
	// set driver parameters
	// set internal parameters
	jackctl_server_open(server, jackctl_server_get_driver(server, driver_name));
	jackctl_server_start(server);
	jackctl_server_load_internal(server, jackctl_server_get_internal(server, client_name));

	signals = jackctl_setup_signals(0);
	jackctl_wait_signals(signals);

	jackctl_server_stop(server);
	jackctl_server_close(server);
	jackctl_server_destroy(server);

** However, I don't see the point.  The purpose of jackctl_setup_signals(0) appears to be
** to block all signals from the server threads while unblocking them on the control thread
** so the control thread can go to sleep and wait for a signal, so it can stop the server
** thread.  But why should the server control be limited to that way of waiting for the
** shutdown?
*/

static char *jack_parameter_types[] = { "none", "int", "uint", "char", "string", "bool", NULL };
static char *jack_driver_types[] = { "none", "master", "slave", NULL };

static Tcl_Obj *_make_pointer(void *pointer) {
  // fprintf(stderr, "make pointer %lu\n", (long int)pointer);
#if __WORDSIZE == 64
return Tcl_NewLongObj((long)pointer);
#elif __WORDSIZE == 32
  return Tcl_NewIntObj((int)pointer);
#else
#error "sizeof(void *) isn't obvious"
#endif
}
static Tcl_Obj *_make_value(jackctl_parameter_t *parameter, union jackctl_parameter_value value) {
  switch (jackctl_parameter_get_type(parameter)) {
  case JackParamInt: return Tcl_NewIntObj(value.i);
  case JackParamUInt: return Tcl_NewIntObj(value.ui);
  case JackParamChar: return Tcl_NewStringObj(&value.c, 1);
  case JackParamString: return Tcl_NewStringObj(value.str, -1);
  case JackParamBool: return Tcl_NewBooleanObj(value.b);
  default: return Tcl_ObjPrintf("unknown type %d returned by jackctl_parameter_get_type", jackctl_parameter_get_type(parameter));
  }
}

static int _return_bool(Tcl_Interp *interp, int value) {
  return fw_success_obj(interp, Tcl_NewBooleanObj(value));
}
static int _return_char(Tcl_Interp *interp, char value) {
  return fw_success_obj(interp, Tcl_NewStringObj(&value, 1));
}
static int _return_int(Tcl_Interp *interp, int value) {
  return fw_success_obj(interp, Tcl_NewIntObj(value));
}
static int _return_list(Tcl_Interp *interp, const JSList *list) {
  Tcl_Obj *result = Tcl_NewObj();
  while (list != NULL) {
    if (Tcl_ListObjAppendElement(interp, result, _make_pointer(list->data)) != TCL_OK) {
      Tcl_DecrRefCount(result);
      return TCL_ERROR;
    } else {
      list = jack_slist_next(list);
    }
  }
  return fw_success_obj(interp, result);
}
static int _return_pointer(Tcl_Interp *interp, void *pointer) {
  return fw_success_obj(interp, _make_pointer(pointer));
}
static int _return_string(Tcl_Interp *interp, const char *string) {
  // fprintf(stderr, "return new string obj {%s}\n", string);
  Tcl_Obj *newstring = Tcl_NewStringObj(string, -1);
  // fprintf(stderr, "new string obj {%s}\n", Tcl_GetString(newstring));
  int x = fw_success_obj(interp, newstring);
  // fprintf(stderr, "success returned %d\n", x);
  return x;
}
static int _return_value(Tcl_Interp *interp, jackctl_parameter_t *parameter, union jackctl_parameter_value value) {
  return fw_success_obj(interp, _make_value(parameter, value));
}
static int _get_pointer(Tcl_Interp *interp, Tcl_Obj *value, void **pointer) {
#if __WORDSIZE == 64
  return Tcl_GetLongFromObj(interp, value, (long *)pointer);
#elif __WORDSIZE == 32
  return Tcl_GetIntFromObj(interp, value, (int *)pointer);
#else
#error "sizeof(void *) isn't obvious"
#endif
}
static int _get_value(Tcl_Interp *interp, jackctl_parameter_t *parameter, Tcl_Obj *value, union jackctl_parameter_value *result) {
  switch (jackctl_parameter_get_type(parameter)) {
  case JackParamInt: return Tcl_GetIntFromObj(interp, value, &result->i);
  case JackParamUInt: return Tcl_GetIntFromObj(interp, value, &result->ui);
  case JackParamChar: {
    int length;
    result->c = *Tcl_GetStringFromObj(value, &length);
    if (length == 1)
      return TCL_OK;
    return fw_error_str(interp, "character parameter is not one character long");
  }
  case JackParamString: {
    int length;
    strncpy(result->str, Tcl_GetStringFromObj(value, &length), JACK_PARAM_STRING_MAX);
    if (length <= JACK_PARAM_STRING_MAX)
      return TCL_OK;
    return fw_error_str(interp, "string parameter is too long");
  }
  case JackParamBool: {
    int b;
    if (Tcl_GetBooleanFromObj(interp, value, &b) != TCL_OK)
      return TCL_ERROR;
    result->b = b;
    return TCL_OK;
  }  
  }
  return fw_error_obj(interp, Tcl_ObjPrintf("unknown type %d returned by jackctl_parameter_get_type", jackctl_parameter_get_type(parameter)));
}

// sigset_t jackctl_setup_signals(unsigned int flags);
static int _setup_signals(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return fw_error_str(interp, "usage: jack-ctl setup-signals");
  jackctl_setup_signals(0);
  return TCL_OK;
}

// void jackctl_wait_signals(sigset_t signals);

// jackctl_server_t *jackctl_server_create(bool (* on_device_acquire)(const char * device_name), void (* on_device_release)(const char * device_name));
static int _create(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return fw_error_str(interp, "usage: jack-ctl create");
  return _return_pointer(interp, jackctl_server_create(NULL, NULL));
}
// void jackctl_server_destroy(jackctl_server_t * server);
static int _destroy(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl destroy server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  jackctl_server_destroy(server);
  return TCL_OK;
}
// bool jackctl_server_open(jackctl_server_t * server, jackctl_driver_t * driver);
static int _open(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl open server driver");
  jackctl_server_t * server;
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_open(server, driver));
}
// bool jackctl_server_start(jackctl_server_t * server);
static int _start(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl start server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_bool(interp, jackctl_server_start(server));
}
// bool jackctl_server_stop(jackctl_server_t * server);
static int _stop(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl stop server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_bool(interp, jackctl_server_stop(server));
}
// bool jackctl_server_close(jackctl_server_t * server);
static int _close(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl close server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_bool(interp, jackctl_server_close(server));
}
// const JSList *jackctl_server_get_drivers_list(jackctl_server_t * server);
static int _get_drivers(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl get-drivers server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_list(interp, jackctl_server_get_drivers_list(server));
}
// const JSList *jackctl_server_get_parameters(jackctl_server_t * server);
static int _get_parameters(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl get-parameters server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_list(interp, jackctl_server_get_parameters(server));
}
// const JSList *jackctl_server_get_internals_list(jackctl_server_t * server);
static int _get_internals(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl get-internals server");
  jackctl_server_t * server;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK) return TCL_ERROR;
  return _return_list(interp, jackctl_server_get_internals_list(server));
}
// bool jackctl_server_load_internal(jackctl_server_t * server, jackctl_internal_t * internal);
static int _load_internal(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl load-internal server internal");
  jackctl_server_t * server;
  jackctl_internal_t * internal;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&internal) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_load_internal(server, internal));
}
// bool jackctl_server_unload_internal(jackctl_server_t * server, jackctl_internal_t * internal);
static int _unload_internal(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl unload-internal server internal");
  jackctl_server_t * server;
  jackctl_internal_t * internal;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&internal) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_unload_internal(server, internal));
}
// bool jackctl_server_add_slave(jackctl_server_t * server, jackctl_driver_t * driver);
static int _add_slave(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl add-slave server driver");
  jackctl_server_t * server;
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_add_slave(server, driver));
}
// bool jackctl_server_remove_slave(jackctl_server_t * server, jackctl_driver_t * driver);
static int _remove_slave(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl remove-slave server driver");
  jackctl_server_t * server;
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_remove_slave(server, driver));
}
// bool jackctl_server_switch_master(jackctl_server_t * server, jackctl_driver_t * driver);
static int _switch_master(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl switch-master server driver");
  jackctl_server_t * server;
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&server) != TCL_OK ||
      _get_pointer(interp, objv[3], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_server_switch_master(server, driver));
}

// const char *jackctl_driver_get_name(jackctl_driver_t * driver);
static int _driver_get_name(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl driver-get-name driver");
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  // fprintf(stderr, "driver = %lu\n", (long)driver);
  return _return_string(interp, jackctl_driver_get_name(driver));
}
#if 0				// not in jack-1.9.7
// jackctl_driver_type_t jackctl_driver_get_type(jackctl_driver_t * driver);
static int _driver_get_type(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl driver-get-type driver");
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jack_driver_types[jackctl_driver_get_type(driver)]);
}
#endif
// const JSList *jackctl_driver_get_parameters(jackctl_driver_t * driver);
static int _driver_get_parameters(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl driver-get-parameters driver");
  jackctl_driver_t * driver;
  if (_get_pointer(interp, objv[2], (void**)&driver) != TCL_OK)
    return TCL_ERROR;
  return _return_list(interp, jackctl_driver_get_parameters(driver));
}

// const char *jackctl_internal_get_name(jackctl_internal_t * internal);
static int _internal_get_name(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl internal-get-name internal");
  jackctl_internal_t * internal;
  if (_get_pointer(interp, objv[2], (void**)&internal) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jackctl_internal_get_name(internal));
}
// const JSList *jackctl_internal_get_parameters(jackctl_internal_t * internal);
static int _internal_get_parameters(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl internal-get-parameters internal");
  jackctl_internal_t * internal;
  if (_get_pointer(interp, objv[2], (void**)&internal) != TCL_OK)
    return TCL_ERROR;
  return _return_list(interp, jackctl_internal_get_parameters(internal));
}

// const char *jackctl_parameter_get_name(jackctl_parameter_t * parameter);
static int _parameter_get_name(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-name parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jackctl_parameter_get_name(parameter));
}
// const char *jackctl_parameter_get_short_description(jackctl_parameter_t * parameter);
static int _parameter_get_short_description(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-short-description parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jackctl_parameter_get_short_description(parameter));
}
// const char *jackctl_parameter_get_long_description(jackctl_parameter_t * parameter);
static int _parameter_get_long_description(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-long-description parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jackctl_parameter_get_long_description(parameter));
}
// jackctl_param_type_t jackctl_parameter_get_type(jackctl_parameter_t * parameter);
static int _parameter_get_type(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-type parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jack_parameter_types[jackctl_parameter_get_type(parameter)]);

}
// char jackctl_parameter_get_id(jackctl_parameter_t * parameter);
static int _parameter_get_id(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-id parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_char(interp, jackctl_parameter_get_id(parameter));
}
// bool jackctl_parameter_is_set(jackctl_parameter_t * parameter);
static int _parameter_is_set(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-is-set parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_is_set(parameter));
}
// bool jackctl_parameter_reset(jackctl_parameter_t * parameter);
static int _parameter_reset(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-reset parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_reset(parameter));
}
// union jackctl_parameter_value jackctl_parameter_get_value(jackctl_parameter_t * parameter);
static int _parameter_get_value(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-value parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_value(interp, parameter, jackctl_parameter_get_value(parameter));
}
// bool jackctl_parameter_set_value(jackctl_parameter_t * parameter, const union jackctl_parameter_value * value_ptr);
static int _parameter_set_value(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl parameter-set-value parameter value");
  jackctl_parameter_t * parameter;
  union jackctl_parameter_value value;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK ||
      _get_value(interp, parameter, objv[3], &value) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_set_value(parameter, &value));
}
// union jackctl_parameter_value jackctl_parameter_get_default_value(jackctl_parameter_t * parameter);
static int _parameter_get_default_value(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-default-value parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_value(interp, parameter, jackctl_parameter_get_default_value(parameter));
}
// bool jackctl_parameter_has_range_constraint(jackctl_parameter_t * parameter);
static int _parameter_has_range_constraint(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-has-range-constraint parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_has_range_constraint(parameter));
}
// bool jackctl_parameter_has_enum_constraint(jackctl_parameter_t * parameter);
static int _parameter_has_enum_constraint(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-has-enum-constraint parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_has_enum_constraint(parameter));
}
// uint32_t jackctl_parameter_get_enum_constraints_count(jackctl_parameter_t * parameter);
static int _parameter_get_enum_constraints_count(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-enum-constraints-count parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_int(interp, jackctl_parameter_get_enum_constraints_count(parameter));
}
// union jackctl_parameter_value jackctl_parameter_get_enum_constraint_value(jackctl_parameter_t * parameter, uint32_t index);
static int _parameter_get_enum_constraint_value(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl parameter-get-enum-constraint-value parameter index");
  jackctl_parameter_t * parameter;
  int index;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK ||
      Tcl_GetIntFromObj(interp, objv[3], &index) != TCL_OK)
    return TCL_ERROR;
  return _return_value(interp, parameter, jackctl_parameter_get_enum_constraint_value(parameter, index));
}
// const char *jackctl_parameter_get_enum_constraint_description(jackctl_parameter_t * parameter, uint32_t index);
static int _parameter_get_enum_constraint_description(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 4) return fw_error_str(interp, "usage: jack-ctl parameter-get-enum-constraint-description parameter index");
  jackctl_parameter_t * parameter;
  int index;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK ||
      Tcl_GetIntFromObj(interp, objv[3], &index) != TCL_OK)
    return TCL_ERROR;
  return _return_string(interp, jackctl_parameter_get_enum_constraint_description(parameter, index));
}
// void jackctl_parameter_get_range_constraint(jackctl_parameter_t * parameter, union jackctl_parameter_value * min_ptr, union jackctl_parameter_value * max_ptr);
static int _parameter_get_range_constraint(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-get-range-constraint parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  union jackctl_parameter_value min, max;
  jackctl_parameter_get_range_constraint(parameter, &min, &max);
  Tcl_Obj *result[] = { _make_value(parameter, min), _make_value(parameter, max), NULL };
  return fw_success_obj(interp, Tcl_NewListObj(2, result));
}
// bool jackctl_parameter_constraint_is_strict(jackctl_parameter_t * parameter);
static int _parameter_constraint_is_strict(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-constraint-is-strict parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_constraint_is_strict(parameter));
}
// bool jackctl_parameter_constraint_is_fake_value(jackctl_parameter_t * parameter);
static int _parameter_constraint_is_fake_value(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl parameter-constraint-is-fake parameter");
  jackctl_parameter_t * parameter;
  if (_get_pointer(interp, objv[2], (void**)&parameter) != TCL_OK)
    return TCL_ERROR;
  return _return_bool(interp, jackctl_parameter_constraint_is_fake_value(parameter));
}

// void jack_error(const char *format, ...);
static int _error(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl error string");
  jack_error(Tcl_GetStringFromObj(objv[2], NULL));
  return TCL_OK;
}
// void jack_info(const char *format, ...);
static int _info(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl info string");
  jack_info(Tcl_GetStringFromObj(objv[2], NULL));
  return TCL_OK;
}
// void jack_log(const char *format, ...);
static int _log(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 3) return fw_error_str(interp, "usage: jack-ctl log string");
  jack_log(Tcl_GetStringFromObj(objv[2], NULL));
  return TCL_OK;
}

static const fw_subcommand_table_t _subcommands[] = {
  { "create", _create, "create a jack server object" },
  { "destroy",_destroy, "get the jack server buffer size" },
  { "open",   _open, "" },
  { "start",_start, "" },
  { "stop", _stop, "" },
  { "close", _close, "" },
  { "get-drivers", _get_drivers, "" },
  { "get-parameters", _get_parameters, "" },
  { "get-internals", _get_internals, "" },
  { "load-internal", _load_internal, "" },
  { "unload-internal", _unload_internal, "" },
  { "add-slave", _add_slave, "" },
  { "remove-slave", _remove_slave, "" },
  { "switch-master", _switch_master, "" },

  { "driver-get-name", _driver_get_name, "" },
#if 0
  { "driver-get-type", _driver_get_type, "" },
#endif
  { "driver-get-parameters", _driver_get_parameters, "" },

  { "internal-get-name", _internal_get_name, "" },
  { "internal-get-parameters", _internal_get_parameters, "" },

  { "parameter-get-name", _parameter_get_name, "" },
  { "parameter-get-short-description", _parameter_get_short_description, "" }, 
  { "parameter-get-long-description", _parameter_get_long_description, "" },
  { "parameter-get-type", _parameter_get_type, "" },
  { "parameter-get-id", _parameter_get_id, "" },
  { "parameter-is-set", _parameter_is_set, "" },
  { "parameter-reset", _parameter_reset, "" },
  { "parameter-get-value", _parameter_get_value, "" },
  { "parameter-set-value", _parameter_set_value, "" },
  { "parameter-get-default-value", _parameter_get_default_value, "" },
  { "parameter-has-range-constraint", _parameter_has_range_constraint, "" },
  { "parameter-has-enum-constraint", _parameter_has_enum_constraint, "" },
  { "parameter-get-enum-constraints-count", _parameter_get_enum_constraints_count, "" },
  { "parameter-get-enum-constraint-value", _parameter_get_enum_constraint_value, "" },
  { "parameter_get-enum-constraint-description", _parameter_get_enum_constraint_description, "" },
  { "parameter-get-range-constraint", _parameter_get_range_constraint, "" },
  { "parameter-constraint-is-strict", _parameter_constraint_is_strict, "" },
  { "parameter-constraint-is-fake-value", _parameter_constraint_is_fake_value, "" },

  { "error", _error, "" },
  { "info", _info, "" },
  { "log", _log, "" },
  { NULL }
};

// the command which returns jack client information
// and implements port management
// on the jack server it opened
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  const fw_subcommand_table_t *table = _subcommands;
  if (argc < 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s subcommand [ ... ]", Tcl_GetString(objv[0])));
  char *subcmd = Tcl_GetString(objv[1]);
  for (int i = 0; table[i].name != NULL; i += 1)
    if (strcmp(subcmd, table[i].name) == 0)
      return table[i].handler(clientData, interp, argc, objv);
  return fw_error_obj(interp, Tcl_ObjPrintf("unrecognized subcommand \"%s\"", subcmd));
}

// the initialization function which install the jack-client factory
int DLLEXPORT Jack_ctl_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::jack-ctl", "1.0.0", "sdrtcl::jack-ctl", _command);
}

