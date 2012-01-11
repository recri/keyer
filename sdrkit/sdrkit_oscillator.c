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

/*
** This should be widget configure|cget|start|stop
** options: -frequency hertz -phase angle -gain dB
** actually, phase doesn't work as an option
*/
#include "sdrkit.h"

#include "../dspkit/oscillator.h"

typedef struct {
  SDRKIT_T_COMMON;
  oscillator_t o;
  int modified;
  float hertz;
  float dBgain;
  float gain;
  int sample_rate;
} _t;

static void _update(_t *data) {
  if (data->modified) {
    data->modified = 0;
    oscillator_update(&data->o, data->hertz, data->sample_rate);
    data->gain = powf(10, data->dBgain / 20);
  }
}
  
static void *_init(void *arg) {
  _t * const data = (_t *)arg;
  data->modified = 0;
  data->hertz = 440.0f;
  data->dBgain = -30;
  data->gain = powf(10, data->dBgain / 20);
  data->sample_rate = sdrkit_sample_rate(data);
  oscillator_init(&data->o, data->hertz, data->sample_rate);
  return arg;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  float *out0 = jack_port_get_buffer(data->port[0], nframes);
  float *out1 = jack_port_get_buffer(data->port[1], nframes);
  for (int i = nframes; --i >= 0; ) {
    _update(data);
    float _Complex z = data->gain * oscillator(&data->o);
    *out0++ = creal(z);
    *out1++ = cimag(z);
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_ObjPrintf("-frequency %f -gain %f", data->hertz, data->gain));
  if (argc == 3) {
    char *opt = Tcl_GetString(objv[1]);
    if (strcmp(opt, "-frequency") == 0) {
      float hertz;
      if (sdrkit_get_float(interp, objv[2], &hertz) != TCL_OK)
	return TCL_ERROR;
      if (fabs(hertz) > sdrkit_sample_rate(clientData) / 4) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("frequency %.1f is more than samplerate/4", hertz));
	return TCL_ERROR;
      }
      if (hertz != data->hertz) {
	data->modified = 1;
	data->hertz = hertz;
      }
      return TCL_OK;
    }
    if (strcmp(opt, "-gain") == 0) {
      float dBgain;
      if (sdrkit_get_float(interp, objv[2], &dBgain) != TCL_OK)
	return TCL_ERROR;
      if (dBgain != data->dBgain) {
	data->modified = 1;
	data->dBgain = dBgain;
      }
      return TCL_OK;
    }
  }
 usage:
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-frequency hertz]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 0, 2, 0, 0, _command, _process, sizeof(_t), _init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_oscillator_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit::oscillator", "1.0.0", "sdrkit::oscillator", _factory);
}
