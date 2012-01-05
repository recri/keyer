/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"

/*
** Create a tap to buffer samples for processing in the background.
**
** Background thinking has come to the conclusion that we allocate a
** humongous buffer and circularly stream samples into it.  Tcl gets
** the largest contiguous chunk available along with the frame time for
** the start of the chunk.
**
** The buffer is ATAP_N_SECONDS * sample_rate * 2 floats, rounded up
** to a buffer size.
**
** And they're not interleaved by sample, they're interleaved by jack
** buffer size.  You get nframes of I followed by nframes of Q, because
** that's what the tap delivers fastest.
*/

#ifndef ATAP_N_SECONDS
#define ATAP_N_SECONDS 2 
#endif

typedef struct {
  SDRKIT_T_COMMON;
  jack_nframes_t wframe;
  jack_nframes_t rframe;
  size_t wptr;
  size_t rptr;
  size_t size;
  float *buffer;
} atap_t;

static void atap_init(void *arg) {
  atap_t *data = (atap_t *)arg;
  data->wframe = 0;
  data->rframe = 0;
  data->wptr = 0;
  data->rptr = 0;
  unsigned n_buffers = (ATAP_N_SECONDS * sdrkit_sample_rate(arg) + sdrkit_buffer_size(arg)) / sdrkit_buffer_size(arg);
  data->size = n_buffers*sdrkit_buffer_size(arg)*2*sizeof(float);
  if (data->size == 0 || (data->size & (data->size-1)) != 0)
    fprintf(stderr, "%s:%d: buffer size computation yielded 0x%lx\n", __FILE__, __LINE__, data->size);
  data->buffer = (float *)Tcl_Alloc(data->size);
  if (data->buffer == NULL)
    fprintf(stderr, "%s:%d: allocation of %ld bytes failed\n", __FILE__, __LINE__, data->size);
}

static void atap_delete(void *arg) {
  atap_t *data = (atap_t *)arg;
  void *buffer = (void *)data->buffer;
  data->buffer = NULL;
  Tcl_Free(buffer);
}

static int atap_process(jack_nframes_t nframes, void *arg) {
  atap_t *data = (atap_t *)arg;
  data->wframe = sdrkit_last_frame_time(arg);
  float *in0 = jack_port_get_buffer(data->port[0], nframes);
  if (in0) memcpy(data->buffer+data->wptr, in0, nframes*sizeof(float));
  else memset(data->buffer+data->wptr, 0, nframes*sizeof(float));
  data->wptr += nframes;
  data->wptr &= data->size-1;
  float *in1 = jack_port_get_buffer(data->port[1], nframes);
  if (in1) memcpy(data->buffer+data->wptr, in1, nframes*sizeof(float));
  else memset(data->buffer+data->wptr, 0, nframes*sizeof(float));
  data->wptr += nframes;
  data->wptr &= data->size-1;
  if (data->rptr == data->wptr) {
    data->rptr += 2*nframes;
    data->rptr &= data->size-1;
  }
  return 0;
}

static int atap_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  atap_t *data = (atap_t *)clientData;
  if (argc == 1) {
    // return tap buffer
    unsigned char *p = (unsigned char *)(data->buffer+data->rptr);
    size_t n = ((data->rptr < data->wptr) ? data->wptr : data->size) - data->rptr;
    Tcl_Obj *result[] = {
      Tcl_NewIntObj(data->rframe), 
      Tcl_NewByteArrayObj(p, n*sizeof(float)),
      NULL
    };
    data->rptr += n;
    data->rptr &= data->size-1;
    data->rframe += n/2;
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
    return TCL_OK;
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int atap_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 0, 0, 0, atap_command, atap_process, sizeof(atap_t), atap_init, atap_delete);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_atap_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::atap", atap_factory);
}
