/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"

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
} mixer_t;

static void mixer_init(void *arg) {
}

static int mixer_process(jack_nframes_t nframes, void *arg) {
  mixer_t *data = (mixer_t *)arg;
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

static int mixer_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 1)
    return sdrkit_return_values(interp, Tcl_NewStringObj("", 0));
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s", Tcl_GetString(objv[0])));
  return TCL_ERROR;
}

static int mixer_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 4, 2, 0, 0, mixer_command, mixer_process, sizeof(mixer_t), mixer_init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_mixer_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::mixer", mixer_factory);
}
