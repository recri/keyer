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
#include "../dspkit/window.h"

#include <complex.h>
#include <fftw3.h>


/*
** create a complex 1d fft
** size of fft as parameter to factory
*/
typedef struct {
  int size;			/* number of complex floats */
  fftwf_complex *inout;		/* input/output array */
  fftwf_plan plan;		/* fftw plan */
  float *window;		/* window */
} _t;

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data != NULL) {
    if (data->plan != NULL) fftwf_destroy_plan(data->plan);
    if (data->inout != NULL) fftwf_free(data->inout);
    if (data->window != NULL) fftwf_free(data->window);
    Tcl_Free((void *)data);
  }
}

static _t *_init(int size, int planbits, int window_type) {
  _t *data = (_t *)Tcl_Alloc(sizeof(_t));
  if (data == NULL) return NULL;
  memset((void *)data, 0, sizeof(_t));
  data->size = size;
  if ((data->inout = (fftwf_complex *)fftwf_malloc(data->size*sizeof(fftwf_complex))) &&
      (data->window = (float *)fftwf_malloc(data->size*sizeof(float))) &&
      (data->plan = fftwf_plan_dft_1d(data->size,  data->inout, data->inout, FFTW_FORWARD, planbits))) {
    window_make(window_type, data->size, data->window);
    return data;
  } else {
    _delete(data);
    return NULL;
  }
}

/*
** The command executes a complex fft given an input byte array
** of interleaved i/q of the correct size.
**
** The result is returned as a byte array of complex coefficients
** in the fftw standard order.
**
** The result is stored into a new byte array or into the optional
** second output byte array argument, which may be the same as the
** input byte array.
*/
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  float _Complex *input;
  Tcl_Obj *output = NULL;
  // check the argument count
  if (argc < 2 || argc > 3) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s input_byte_array [ output_byte_array ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  // check the input byte array
  if ((input = (float _Complex *)Tcl_GetByteArrayFromObj(objv[1], &n)) == NULL || n < data->size*2*sizeof(float)) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("byte_array argument does have not %d samples", data->size));
    return TCL_ERROR;
  }
  // copy the input into the input buffer, applying the window
  for (int i = 0; i < data->size; i += 1) {
    data->inout[i] = data->window[i] * *input++;
  }
  // compute the fft
  fftwf_execute(data->plan);
  // create the result
  Tcl_Obj *result;
  if (argc == 2) {
    result = Tcl_NewByteArrayObj((unsigned char *)data->inout, data->size*2*sizeof(float));
  } else {
    Tcl_SetByteArrayObj(result = objv[2], (unsigned char *)data->inout, data->size*2*sizeof(float));
  }
  // set the result
  Tcl_SetObjResult(interp,result);
  // return success
  return TCL_OK;
}

/*
** The factory command creates an fft command with specified
** command name, size of fft, fftw planbits, and window.
** could supply the window as a byte array.
*/
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  char *command_name;
  int size = 4096, planbits = 0, window_type = WINDOW_BLACKMANHARRIS;
  if (argc >= 2 || argc <= 5) {
    command_name = Tcl_GetString(objv[1]);
    if (argc > 2) {
      if (Tcl_GetIntFromObj(interp, objv[2], &size) != TCL_OK) {
	return TCL_ERROR;
      } else if (argc > 3) {
	if (Tcl_GetIntFromObj(interp, objv[3], &planbits) != TCL_OK) {
	  return TCL_ERROR;
	} else if (argc > 4) {
	  if (Tcl_GetIntFromObj(interp, objv[4], &window_type) != TCL_OK) {
	    return TCL_ERROR;
	  }
	}
      }
    }
    // fprintf(stderr, "calling _init(%d, %x)\n", size, planbits);
    _t *data = _init(size, planbits, window_type);
    if (data == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("allocation failed", -1));
      return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, command_name, _command, (ClientData)data, _delete);
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s command_name [ size [ planbits [ window_type ] ] ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_fftw_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::fftw", _factory);
}
