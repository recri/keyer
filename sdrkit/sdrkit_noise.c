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

#define _XOPEN_SOURCE 500
#include <stdlib.h>

/*
** make noise, specified dB level
*/
typedef struct {
  SDRKIT_T_COMMON;
  float gain;
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->gain = 0.0001;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *out0 = jack_port_get_buffer(data->port[0], nframes);
  float *out1 = jack_port_get_buffer(data->port[1], nframes);
  AVOIDDENORMALS;
  for (int i = nframes; --i >= 0; ) {
    *out0++ = data->gain * 4 * (0.5 - (random() / (float)RAND_MAX));
    *out1++ = data->gain * 4 * (0.5 - (random() / (float)RAND_MAX));
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc == 1) {
    Tcl_SetObjResult(interp, Tcl_NewDoubleObj(20*log10(data->gain)));
    return TCL_OK;
  }
  if (argc == 2) {
    float dBgain;
    if (sdrkit_get_float(interp, objv[1], &dBgain) == TCL_OK) {
      data->gain = powf(10, dBgain / 20);
      return TCL_OK;
    }
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 0, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_noise_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::noise", _factory);
}
