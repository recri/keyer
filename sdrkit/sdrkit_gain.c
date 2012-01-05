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
** create a gain module which scales its inputs by a scalar
** and stores them into the outputs.
** a contraction of a real constant and mixer.
** one scalar parameter.
*/
typedef struct {
  SDRKIT_T_COMMON;
  float igain, qgain;
} gain_t;

static void gain_init(void *arg) {
  ((gain_t *)arg)->igain = ((gain_t *)arg)->qgain = 1.0f;
}

static int gain_process(jack_nframes_t nframes, void *arg) {
  const gain_t *data = (gain_t *)arg;
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  float *out0 = jack_port_get_buffer(data->port[2], nframes);
  float *out1 = jack_port_get_buffer(data->port[3], nframes);
  AVOIDDENORMALS;
  for (int i = nframes; --i >= 0; ) {
    *out0++ = data->igain * *in0++;
    *out1++ = data->qgain * *in1++;
  }
  return 0;
}

static int gain_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  gain_t *data = (gain_t *)clientData;
  float gain = 0;
  if (argc == 1) {
    if (data->igain == data->qgain)
      return sdrkit_return_values(interp, Tcl_ObjPrintf("-gain %f", data->igain));
    else
      return sdrkit_return_values(interp, Tcl_ObjPrintf("-igain %f -qgain %f", data->igain, data->qgain));
  }
  if (argc == 3 || argc == 5) {
    for (int i = 1; i < argc; i += 2) {
      char *opt = Tcl_GetString(objv[i]);
      if (strcmp(opt, "-gain") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &gain) != TCL_OK)
	  return TCL_ERROR;
	data->igain = data->qgain = gain;
      } else if (strcmp(opt, "-igain") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &gain) != TCL_OK)
	  return TCL_ERROR;
	data->igain = gain;
      } else if (strcmp(opt, "-qgain") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &gain) != TCL_OK)
	  return TCL_ERROR;
	data->qgain = gain;
      } else {
	goto usage;
      }
    }
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-gain|-igain|-qgain value]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int gain_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, gain_command, gain_process, sizeof(gain_t), gain_init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_gain_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::gain", gain_factory);
}

