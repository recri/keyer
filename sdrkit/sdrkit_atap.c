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
** Create an audio tap to extract samples for processing outside
** the Jack process thread in Tcl.
**
** The buffer is _N_MILLI_SECONDS * sample_rate * 2 floats, rounded up
** to a power of two.
**
** A separate buffer is kept for the I and Q channels.
**
** Tcl gets the most recent chunk available along with the frame time for
** the start of the chunk for the size requested.  And the result byte
** array is floats interleaved i/q by sample, so I don't have to explain
** why it isn't.
*/

#ifndef _N_MILLI_SECONDS
#define _N_MILLI_SECONDS 250
#endif

typedef struct {
  SDRKIT_T_COMMON;
  jack_nframes_t wframe;	// current write frame time
  size_t size;			// number of floats allocated, power of two
  float *ibuffer;		// buffer for i samples
  float *qbuffer;		// buffer for q samples
} _t;

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->wframe = 0;
  unsigned n_buffers = (_N_MILLI_SECONDS * sdrkit_sample_rate(arg)) / (sdrkit_buffer_size(arg) * 1000);
  if ((n_buffers & (n_buffers-1)) != 0) {
    // fprintf(stderr, "n_buffers %x\n", n_buffers);
    n_buffers = pow(2, 1+(int)(log10(n_buffers)/log10(2)));
    // fprintf(stderr, "n_buffers %x\n", n_buffers);
  }
  data->size = n_buffers*sdrkit_buffer_size(arg);	 // this is floats
  if (data->size == 0 || (data->size & (data->size-1)) != 0) {
    fprintf(stderr, "%s:%d: buffer size computation yielded 0x%lx\n", __FILE__, __LINE__, data->size);
    return NULL;
  }
  data->ibuffer = (float *)Tcl_Alloc(data->size*sizeof(float));
  data->qbuffer = (float *)Tcl_Alloc(data->size*sizeof(float));
  if (data->ibuffer == NULL || data->qbuffer == NULL) {
    fprintf(stderr, "%s:%d: allocation of %ld bytes failed\n", __FILE__, __LINE__, data->size);
    if (data->ibuffer != NULL) Tcl_Free((void *)data->ibuffer);
    data->ibuffer = NULL;
    if (data->qbuffer != NULL) Tcl_Free((void *)data->qbuffer);
    data->qbuffer = NULL;
    return NULL;
  }
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->ibuffer != NULL) Tcl_Free((void *)data->ibuffer);
  data->ibuffer = NULL;
  if (data->qbuffer != NULL) Tcl_Free((void *)data->qbuffer);
  data->qbuffer = NULL;
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;

  data->wframe = sdrkit_last_frame_time(arg);

  size_t offset = (data->wframe&(data->size-1));
  if (offset + nframes > data->size) {
    fprintf(stderr, "offset = %ld + nframes = %ld > size = %ld\n", offset, (long)nframes, data->size);
    // need to implement a misaligned copy/set, but I'm betting that jacks frame time is
    // buffer aligned
  } else {
    float *in0 = jack_port_get_buffer(data->port[0], nframes);
    if (in0) memcpy(data->ibuffer+offset, in0, nframes*sizeof(float));
    else memset(data->ibuffer+offset, 0, nframes*sizeof(float));

    float *in1 = jack_port_get_buffer(data->port[1], nframes);
    if (in1) memcpy(data->qbuffer+offset, in1, nframes*sizeof(float));
    else memset(data->qbuffer+offset, 0, nframes*sizeof(float));
  }

  data->wframe += nframes;

  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;

  if (argc < 2 || argc > 3) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s n_samples [ output_byte_array ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }

  int n_samples;
  if (Tcl_GetIntFromObj(interp, objv[1], &n_samples) != TCL_OK) {
    return TCL_ERROR;
  }

  if (n_samples > data->size/4) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("%d samples is too many", n_samples));
    return TCL_ERROR;
  }

  jack_nframes_t wframe = data->wframe;
  jack_nframes_t rframe = wframe - n_samples;
  size_t rptr = rframe & (data->size-1);
  Tcl_Obj *result[] = {
    Tcl_NewLongObj(rframe), 
    argc > 2 ? objv[2] : Tcl_NewObj(),
    NULL
  };
  float *samples = (float *)Tcl_SetByteArrayLength(result[1], n_samples*2*sizeof(float));
  if (samples == NULL) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj("failed to allocate result buffer", -1));
    return TCL_ERROR;
  }
  while (--n_samples >= 0) {
    *samples++ = data->ibuffer[rptr];
    *samples++ = data->qbuffer[rptr];
    rptr += 1;
    rptr &= data->size-1;
  }
  Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
  return TCL_OK;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 0, 0, 0, _command, _process, sizeof(_t), _init, _delete);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_atap_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::atap", _factory);
}
