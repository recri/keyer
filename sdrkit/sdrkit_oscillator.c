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
** create an oscillator module which produces samples at a specified frequency
** this breaks down at sample_rate / 4, so run it at a higher sample rate?
** one scalar parameter, the frequency
**
** this is crashing.  I think it might be getting more than one parameter update
** in a processing cycle which would lead to the update overwriting the 
*/
typedef struct {
  float hertz;			/* frequency */
  float wps;			/* wavelength per sample */
  float rps;			/* radians per sample */
  float c;			/* coefficient in the recursion */
  float xi;			/* x at 0 */
  float x, y;			/* values in the recursion */
} oscillator_params_t;

typedef struct {
  SDRKIT_T_COMMON;
  oscillator_params_t *current, p[2];
} oscillator_t;

static inline float squaref(float x) { return x * x; }

static void oscillator_setup(oscillator_params_t *p, float hertz, int sample_rate) {
  p->hertz = hertz;
  p->wps = hertz / sample_rate;
  p->rps = p->wps * 2 * M_PI;
  p->c = sqrtf(1.0 / (1.0 + squaref(tanf(p->rps))));
  p->xi = sqrtf((1.0 - p->c) / (1.0 + p->c));
  p->x = p->xi;
  p->y = 0.0;
}
  
static void oscillator_init(void *arg) {
  oscillator_t * const data = (oscillator_t *)arg;
  data->current = data->p+0;
  oscillator_setup(data->current, 440.0f, sdrkit_sample_rate(data));
}

static int oscillator_process(jack_nframes_t nframes, void *arg) {
  const oscillator_t * const data = (oscillator_t *)arg;
  oscillator_params_t * const p = data->current;
  float *out0 = jack_port_get_buffer(data->port[0], nframes);
  float *out1 = jack_port_get_buffer(data->port[1], nframes);
  double c = p->c, x = p->x, y = p->y;
  AVOIDDENORMALS;
  for (int i = nframes; --i >= 0; ) {
    float t = (x + y) * c;
    float nx = t-y;
    float ny = t+x;
    *out0++ = nx / p->xi;	/* time this and see if a multiply would be better */
    *out1++ = ny;
    x = nx;
    y = ny;
  }
  p->x = x;
  p->y = y;
  return 0;
}

static int oscillator_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  oscillator_t *data = (oscillator_t *)clientData;
  oscillator_params_t *current = data->current;
  oscillator_params_t *next = current == data->p ? data->p+1 : data->p+0;
  float hertz = 0;
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_ObjPrintf("-frequency %f", current->hertz));
  if (argc == 3) {
    char *opt = Tcl_GetString(objv[1]);
    if (strcmp(opt, "-frequency") == 0) {
      if (sdrkit_get_float(interp, objv[2], &hertz) != TCL_OK)
	return TCL_ERROR;
    } else {
      goto usage;
    }
    if (fabs(hertz) > sdrkit_sample_rate(clientData) / 4) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("frequency %.1f is more than samplerate/4", hertz));
      return TCL_ERROR;
    }
    oscillator_setup(next, hertz, sdrkit_sample_rate(clientData));
    next->x = current->x / current->xi * next->xi;
    next->y = current->y;
    data->current = next;
    return TCL_OK;
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-frequency hertz]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int oscillator_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 0, 2, 0, 0, oscillator_command, oscillator_process, sizeof(oscillator_t), oscillator_init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_oscillator_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::oscillator", oscillator_factory);
}
