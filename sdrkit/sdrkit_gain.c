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

#include "sdrkit_math.h"

/*
** create a gain module which scales its inputs by a scalar
** and stores them into the outputs.
** a contraction of a real constant and mixer.
** one scalar parameter.
*/
typedef struct {
  SDRKIT_T_COMMON;
  float _Complex gain;
} _t;

static void *_init(void *arg) {
  ((_t *)arg)->gain = 1.0f;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  const _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  float *out0 = jack_port_get_buffer(data->port[2], nframes);
  float *out1 = jack_port_get_buffer(data->port[3], nframes);
  AVOIDDENORMALS;
  for (int i = nframes; --i >= 0; ) {
    float _Complex z = data-> gain * (*in0++ + I * *in1++);
    *out0++ = crealf(z);
    *out1++ = cimagf(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  float gain = 0;
  if (argc == 1) {
    Tcl_Obj *result[] = {
      Tcl_NewDoubleObj(creal(data->gain)),
      Tcl_NewDoubleObj(cimag(data->gain)),
      NULL
    };
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
    return TCL_OK;
  }
  if (argc == 2) {
    float real;
    if (sdrkit_get_float(interp, objv[1], &real) != TCL_OK)
      return TCL_ERROR;
    data->gain = real;
    return TCL_OK;
  }
  if (argc == 3) {
    float real, imag;
    if (sdrkit_get_float(interp, objv[1], &real) != TCL_OK)
      return TCL_ERROR;
    if (sdrkit_get_float(interp, objv[2], &imag) != TCL_OK)
      return TCL_ERROR;
    data->gain = real + I * imag;
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [ real_gain [ imag_gain ]]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_gain_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::gain", _factory);
}

