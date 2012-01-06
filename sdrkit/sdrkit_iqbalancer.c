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
** create an IQ balancer module which adjusts the phase and relative magnitude of an IQ channel
** two scalar parameters: phase and gain
  for (i = 0; i < CXBhave(sigbuf); i++) {
    COMPLEX y;
    CXBimag(sigbuf, i) += iq->phase * CXBreal(sigbuf, i);
    CXBreal(sigbuf, i) *= iq->gain;
    y = Cadd(CXBdata(sigbuf, i), Cmul(iq->w[0], Conjg(CXBdata(sigbuf, i))));
    iq->w[0] = Csub(Cscl(iq->w[0], 1.0 - iq->mu * 0.000001), Cscl(Cmul(y, y), iq->mu));
    CXBdata(sigbuf, i) = y;
  }
*/
#define _mu 0.25f	/* fudge? const: 0.25 */

typedef struct {
  float phase;			/* phase correction */
  float gain;			/* gain correction */
  _Complex float w;		/* memory? init: 0.00+0.00 * I */
} _params_t;

typedef struct {
  SDRKIT_T_COMMON;
  _params_t *current, p[2];
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->current = data->p+0;
  data->current->phase = 0.0f;
  data->current->gain = 1.0f;
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  float *out0 = jack_port_get_buffer(data->port[2], nframes);
  float *out1 = jack_port_get_buffer(data->port[3], nframes);
  _params_t *p = data->current;
  for (int i = nframes; --i >= 0; ) {
    _Complex float in = *in0++ + *in1++ * I;
    _Complex float adj_in = creal(in) * p->gain + (cimag(in) + p->phase * creal(in)) * I;
    _Complex float y = adj_in + p->w * conj(adj_in);
    p->w = (1.0 - _mu * 0.000001) * p->w - _mu * y * y;
    *out0++ = creal(y);
    *out1++ = cimag(y);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  _params_t *next = data->current == data->p ? data->p+1 : data->p+0;
  float phase = 0, gain = 1.0;
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_ObjPrintf("-phase %f -gain %f", data->current->phase, data->current->gain));
  if (argc == 3 || argc == 5) {
    for (int i = 1; i < argc; i += 2) {
      char *opt = Tcl_GetString(objv[i]);
      if (strcmp(opt, "-phase") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &phase) != TCL_OK)
	  return TCL_ERROR;
      } else if (strcmp(opt, "-gain") == 0) {
	if (sdrkit_get_float(interp, objv[i+1], &gain) != TCL_OK)
	  return TCL_ERROR;
      } else {
	goto usage;
      }
    }
    next->phase = phase;
    next->gain = gain;
    data->current = next;
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-phase value] [-gain value]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_iqbalancer_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::iqbalancer", _factory);
}
