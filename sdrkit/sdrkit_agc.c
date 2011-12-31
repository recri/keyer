/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"

/*
** create an automatic gain control module
** many scalar parameters
*/
typedef struct {
} agc_params_t;

typedef struct {
  SDRKIT_T_COMMON;
  agc_params_t *current, p[2];
} agc_t;
  
static void agc_init(void *arg) {
  agc_t *data = (agc_t *)arg;
  data->current = data->p+0;
}

static int agc_process(jack_nframes_t nframes, void *arg) {
}

static int agc_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
}

static int agc_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, agc_command, agc_process, sizeof(agc_t), agc_init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_agc_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::agc", agc_factory);
}
