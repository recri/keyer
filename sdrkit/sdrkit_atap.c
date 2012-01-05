/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"

/*
** Create a tap to buffer samples for processing in the background.
**
** Background thinking has come to the conclusion that we allocate a
** humongous buffer and circularly stream samples into it.
**
** The buffer is _N_MILLI_SECONDS * sample_rate * 2 floats, rounded up
** to a power of two.
**
** And they're not interleaved by sample, they're interleaved by jack
** buffer size.  You get nframes of I followed by nframes of Q, because
** that's what the tap delivers fastest.
**
** Tcl gets the most recent chunk available along with the frame time for
** the start of the chunk for the size requested.  And the result byte
** array is interleaved i/q by sample, so I don't have to explain why it
** isn't.
*/

#ifndef _N_MILLI_SECONDS
#define _N_MILLI_SECONDS 250
#endif

typedef struct {
  SDRKIT_T_COMMON;
  jack_nframes_t wframe;	// current write frame time
  size_t wptr;			// current write index
  size_t size;			// number of floats allocated
  float *ibuffer;		// buffer for i samples
  float *qbuffer;		// buffer for q samples
} _t;

static void _init(void *arg) {
  _t *data = (_t *)arg;
  data->wframe = 0;
  data->wptr = 0;
  unsigned n_buffers = (_N_MILLI_SECONDS * sdrkit_sample_rate(arg)) / (sdrkit_buffer_size(arg) * 1000);
  if ((n_buffers & (n_buffers-1)) != 0) {
    // fprintf(stderr, "n_buffers %x\n", n_buffers);
    n_buffers = pow(2, 1+(int)(log10(n_buffers)/log10(2)));
    // fprintf(stderr, "n_buffers %x\n", n_buffers);
  }
  data->size = n_buffers*sdrkit_buffer_size(arg);	 // this is floats
  if (data->size == 0 || (data->size & (data->size-1)) != 0)
    fprintf(stderr, "%s:%d: buffer size computation yielded 0x%lx\n", __FILE__, __LINE__, data->size);
  data->ibuffer = (float *)Tcl_Alloc(data->size*sizeof(float));
  data->qbuffer = (float *)Tcl_Alloc(data->size*sizeof(float));
  if (data->ibuffer == NULL || data->qbuffer == NULL) {
    fprintf(stderr, "%s:%d: allocation of %ld bytes failed\n", __FILE__, __LINE__, data->size);
    if (data->ibuffer != NULL) Tcl_Free((void *)data->ibuffer);
    data->ibuffer = NULL;
    if (data->qbuffer != NULL) Tcl_Free((void *)data->qbuffer);
    data->qbuffer = NULL;
    // should abort the rest of the initialization
    // change the framework to return arg or NULL from _init
    // return NULL;
  }
  // return arg;
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

  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  if (in0) memcpy(data->ibuffer+data->wptr, in0, nframes*sizeof(float));
  else memset(data->ibuffer+data->wptr, 0, nframes*sizeof(float));

  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  if (in1) memcpy(data->qbuffer+data->wptr, in1, nframes*sizeof(float));
  else memset(data->qbuffer+data->wptr, 0, nframes*sizeof(float));

  data->wptr += nframes;
  data->wptr &= data->size-1;
  data->wframe = sdrkit_last_frame_time(arg) + nframes;

  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n_samples;
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s n_samples", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], &n_samples) != TCL_OK) {
    return TCL_ERROR;
  }
  jack_nframes_t wframe = data->wframe;
  size_t rptr = (data->wptr - n_samples*2) & (data->size-1);
  Tcl_Obj *result[] = {
    Tcl_NewLongObj(wframe-n_samples/2), 
    Tcl_NewObj(),
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
