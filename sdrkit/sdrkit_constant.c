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

#include "sdrkit.h"

/*
** create a constant module which produces constant samples
** two scalar parameters, the real and imaginary
*/
typedef struct {
  _Complex float c;
} constant_params_t;

typedef struct {
  SDRKIT_T_COMMON;
  constant_params_t *current, p[2];
} constant_t;

static void constant_init(void *arg) {
  constant_t * const data = (constant_t *)arg;
  data->current = &data->p[0];
  data->current->c = 1.0;
  // fprintf(stderr, "constant_init: data %p, data->current %p\n", data, data->current);
}

static int constant_process(jack_nframes_t nframes, void *arg) {
  const constant_t * const data = (constant_t *)arg;
  const constant_params_t * const p = data->current;
  float *out0 = jack_port_get_buffer(data->port[0], nframes);
  float *out1 = jack_port_get_buffer(data->port[1], nframes);
  static int calls = 0;
  //if ((calls++ % 192000) == 0)
    //fprintf(stderr, "constant_process: nframes %d, data %p, params: %p, out0 %p, out1 %p\n", nframes, data, p, out0, out1);
  for (int i = nframes; --i >= 0; ) {
    *out0++ = crealf(p->c);
    *out1++ = cimagf(p->c);
  }
  return 0;
}

static int constant_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  constant_t *data = (constant_t *)clientData;
  constant_params_t *next = data->current == data->p ? data->p+1 : data->p+0;
  float real = 0, imag = 0;
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_ObjPrintf("-real %f -imag %f", creal(data->current->c), cimag(data->current->c)));
  if (argc == 3 || argc == 5) {
    for (int i = 1; i < argc; i += 2) {
      char *opt = Tcl_GetString(objv[i]);
      if (strcmp(opt, "-real") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &real) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-imag") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &imag) != TCL_OK)
	  return TCL_ERROR;
      } else {
	goto usage;
      }
    }
    next->c = real + imag * I;
    data->current = next;
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-real value] [-imag value]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int constant_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 0, 2, 0, 0, constant_command, constant_process, sizeof(constant_t), constant_init, NULL);
}  

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_constant_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::constant", constant_factory);
}
