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
** create a mixer module which combines its inputs into an output
** no parameters.
** if one channel produces a real constant, then this is simply
** a gain block that scales by the real constant.
** if one channel produces a complex constant, then this scales
** and rotates.
*/
typedef struct {
  SDRKIT_T_COMMON;
} _t;

static void *_init(void *arg) {
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  float *in2 = jack_port_get_buffer(data->port[2], nframes);
  float *in3 = jack_port_get_buffer(data->port[3], nframes);
  float *out0 = jack_port_get_buffer(data->port[4], nframes);
  float *out1 = jack_port_get_buffer(data->port[5], nframes);
  AVOIDDENORMALS;
  for (int i = nframes; --i >= 0; ) {
    const _Complex float a = *in0++ + *in1++ * I;
    const _Complex float b = *in2++ + *in3++ * I;
    const _Complex float c = a * b;
    *out0++ = crealf(c);
    *out1++ = cimagf(c);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_NewStringObj("", 0));
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 4, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_mixer_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit::mixer", "1.0.0", "sdrkit::mixer", _factory);
}
