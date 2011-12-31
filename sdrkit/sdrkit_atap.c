/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"

/*
** Create a tap to buffer samples for processing in the background.
**
** The original solution simply buffered samples into a Tcl binary,
** and then returned the binary and a pointer to the current write
** position on demand.
**
** But the Tcl side is going to run slower than the sample side, and
** to keep its buffer of samples stable it would need to immediately
** copy them out to a new binary before the sample side overwrote them,
** and that's a costly operation in Tcl.
**
** So plan B became to maintain a circular buffer of samples
** and fill a Tcl binary with the most recent buffer size on demand.
**
** And plan C became to double buffer.  The Tcl side can supply two buffers, the
** sample side will fill one buffer circularly until the tap contents
** are requested, then switch to the other buffer.
**
** Separate streams or interleaved samples?  It's easier if we interleave.
*/

typedef struct {
  SDRKIT_T_COMMON;
  Tcl_Obj *p_buff, *p_bytes;
  int p_ptr;
} atap_t;

static void atap_init(void *arg) {
  atap_t *data = (atap_t *)arg;
  data->p_ptr = 0;
  Tcl_Obj *bytes = Tcl_NewByteArrayObj("", 0);
  Tcl_IncrRefCount(bytes);
  Tcl_SetByteArrayLength(bytes, 16*1024*2*sizeof(float)); 
  data->p_bytes = bytes;
  Tcl_Obj *buff = Tcl_NewByteArrayObj("", 0);
  Tcl_IncrRefCount(buff);
  Tcl_SetByteArrayLength(buff, 32*1024*2*sizeof(float));
  data->p_buff = buff;
}

static void atap_delete(void *arg) {
  atap_t *data = (atap_t *)arg;
  Tcl_Obj *buff = data->p_buff;
  data->p_buff = NULL;
  Tcl_DecrRefCount(buff);
  Tcl_Obj *bytes = data->p_bytes;
  data->p_bytes = NULL;
  Tcl_DecrRefCount(bytes);
}

static int atap_process(jack_nframes_t nframes, void *arg) {
  atap_t *data = (atap_t *)arg;
  if (data->p_buff != NULL) {
    int length;
    float *buff = (float *)Tcl_GetByteArrayFromObj(data->p_buff, &length);
    float *in0 = jack_port_get_buffer(data->port[0], nframes);
    float *in1 = jack_port_get_buffer(data->port[1], nframes);
    length /= sizeof(float);
    if (in0 && in1) {
      for (int i = nframes; --i >= 0; ) {
	buff[data->p_ptr++] = *in0++;
	buff[data->p_ptr++] = *in1++;
	data->p_ptr &= length - 1;
      }
    } else if (in0) {
      for (int i = nframes; --i >= 0; ) {
	buff[data->p_ptr++] = *in0++;
	buff[data->p_ptr++] = 0;
	data->p_ptr &= length - 1;
      }
    } else if (in1) {
      for (int i = nframes; --i >= 0; ) {
	buff[data->p_ptr++] = 0;
	buff[data->p_ptr++] = *in1++;
	data->p_ptr &= length - 1;
      }
    }
  }
  return 0;
}

static int atap_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  atap_t *data = (atap_t *)clientData;
  if (argc == 1) {
    // return tap buffer
    int buff_length, bytes_length;
    float *buff = (float *)Tcl_GetByteArrayFromObj(data->p_buff, &buff_length);
    float *bytes = (float *)Tcl_GetByteArrayFromObj(data->p_bytes, &bytes_length);
    buff_length /= sizeof(float);
    bytes_length /= sizeof(float);
    int read_ptr = data->p_ptr - bytes_length;
    if (read_ptr >= 0) {
      memcpy(bytes, buff+read_ptr, bytes_length * sizeof(float));
    } else {
      int length1;
      read_ptr &= buff_length-1;
      length1 = buff_length-read_ptr;
      memcpy(bytes, buff+read_ptr, length1*sizeof(float));
      memcpy(bytes+length1, buff, (bytes_length-length1)*sizeof(float));
    }
    Tcl_SetObjResult(interp, data->p_bytes);
    return TCL_OK;
  }
  if (argc >= 3 && strcmp(Tcl_GetString(objv[1]), "-b") == 0) {
    // resize tap buffer
    Tcl_Obj *new_bytes = objv[2];
    int new_bytes_length;
    Tcl_GetByteArrayFromObj(new_bytes, &new_bytes_length);
    if ((new_bytes_length % 2*sizeof(float)) != 0) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("new buffer length %d is not a multiple of %d", new_bytes_length, (int)(2*sizeof(float))));
      return TCL_ERROR;
    }
    if ((new_bytes_length & (new_bytes_length-1)) != 0) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("new buffer length %d is not a power of 2", new_bytes_length));
      return TCL_ERROR;
    }
    // disable buffering for a moment
    Tcl_Obj *buff = data->p_buff;
    data->p_buff = NULL;
    Tcl_SetByteArrayLength(buff, 2*new_bytes_length);
    Tcl_DecrRefCount(data->p_bytes);
    Tcl_IncrRefCount(new_bytes);
    data->p_bytes = new_bytes;
    data->p_ptr = 0;
    // reenable buffering
    data->p_buff = buff;
    return TCL_OK;
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s [-b binary]", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int atap_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 0, 0, 0, atap_command, atap_process, sizeof(atap_t), atap_init, atap_delete);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_atap_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::atap", atap_factory);
}
