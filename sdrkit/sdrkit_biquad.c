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
** create a biquad filter
** five scalar parameters
*/
typedef struct {
  float a1, a2, b0, b1, b2;
  float w11, w12, w21, w22;
} _params_t;

typedef struct {
  SDRKIT_T_COMMON;
  _params_t *current, p[2];
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->current = data->p+0;
  data->current->w11 = data->current->w12 = data->current->w21 = data->current->w22 = 0.0;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  _params_t *p = data->current;
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  float *out0 = jack_port_get_buffer(data->port[2], nframes);
  float *out1 = jack_port_get_buffer(data->port[3], nframes);
  for (int i = nframes; --i >= 0; ) {
    // apply the same filter to i and q separately
    float x1 = *in0++;
    float x2 = *in1++;
    float w10 = x1 - p->a1 * p->w11 + p->a2 * p->w12;
    float w20 = x2 - p->a1 * p->w21 + p->a2 * p->w22;
    float y1 = p->b0 * w10 + p->b1 * p->w11 + p->b2 * p->w12;
    float y2 = p->b0 * w20 + p->b1 * p->w21 + p->b2 * p->w22;
    *out0++ = y1;
    *out1++ = y2;
    p->w12 = p->w11;
    p->w22 = p->w21;
    p->w11 = w10;
    p->w21 = w20;
  }
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  _params_t *current = data->current;
  _params_t *next = current == data->p ? data->p+1 : data->p+0;
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_ObjPrintf("-a1 %f -a2 %f -b0 %f -b1 %f -b2 %f",
						   current->a1, current->a2, current->b0, current->b1, current->b2));
  *next = *current;
  if ((argc & 1) && argc >= 3 && argc <= 11) {
    for (int i = 1; i < argc; i += 2) {
      char *opt = Tcl_GetString(objv[i]);
      if (strcmp(opt, "-a1") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &next->a1) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-a2") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &next->a2) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-b0") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &next->b0) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-b1") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &next->b1) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-b2") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &next->b2) != TCL_OK)
	  return TCL_ERROR;
      } else {
	goto usage;
      }
    }
    data->current = next;
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-a1 value] [-a2 value] [-b0 value] [-b1 value] [-b2 value]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_biquad_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::biquad", _factory);
}
