/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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

#define FRAMEWORK_USES_JACK 0
#define FRAMEWORK_USES_COMMAND 0
#define FRAMEWORK_USES_OPTIONS 0
#define FRAMEWORK_USES_SUBCOMMANDS 0

#include "framework.h"		// shifted up to get window_mode_custom_option table
#include "../dspmath/dspmath.h"

/*
** take the dot product between two sample streams in ByteArrays
*/
static float complex _zdot(int n1, float complex *b1, int o1, int n2, float complex *b2, int o2, int n) {
  float complex sum = 0.0f;
  b1 += o1; n1 -= o1;
  b2 += o2; n2 -= o2;
  n = minf(n, minf(n1, n2));
  for (int i = 0; i < n; i += 1) sum += *b1++ * conjf(*b2++);
  return sum / n;
}
static float _rdot(int n1, float complex *b1, int o1, int n2, float complex *b2, int o2, int n) {
  float sum = 0.0f;
  b1 += o1; n1 -= o1;
  b2 += o2; n2 -= o2;
  n = minf(n, minf(n1, n2));
  for (int i = 0; i < n; i += 1) sum += crealf(*b1++) * crealf(*b2++);
  return sum / n;
}
static float _idot(int n1, float complex *b1, int o1, int n2, float complex *b2, int o2, int n) {
  float sum = 0.0f;
  b1 += o1; n1 -= o1;
  b2 += o2; n2 -= o2;
  n = minf(n, minf(n1, n2));
  for (int i = 0; i < n; i += 1) sum += cimagf(*b1++) * cimagf(*b2++);
  return sum / n;
}
static float complex *_get_buffer(Tcl_Interp *interp, Tcl_Obj *buff, int *np) {
  float complex *b = (float complex *)Tcl_GetByteArrayFromObj(buff, np);
  if ((*np % sizeof(float complex)) != 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("buffer of %d bytes is not an array of float complex", *np));
    return NULL;
  }
  *np /= sizeof(float complex);
  return b;
}
static int _setup(Tcl_Interp *interp, int argc, Tcl_Obj* const *objv, float complex **b1, float complex **b2, int *n1, int *n2, int *o1, int *o2, int *n) {
  if (argc < 3 || argc > 6) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s v1 v2 ?o1 o2? ?n?", Tcl_GetString(objv[0])));
  *b1 = _get_buffer(interp, objv[1], n1);
  if (*b1 == NULL) return TCL_ERROR;
  *b2 = _get_buffer(interp, objv[2], n2);
  if (*b2 == NULL) return TCL_ERROR;
  if (*n1 != *n2) return fw_error_obj(interp, Tcl_ObjPrintf("%s: lengths of v1 and v2 must agree, %d and %d", Tcl_GetString(objv[0]), *n1, *n2));
  switch (argc) {
  case 3:
    *o1 = *o2 = 0;
    *n = *n1;
    break;
  case 4:
    *o1 = *o2 = 0;
    if (Tcl_GetIntFromObj(interp, objv[3], n) != TCL_OK) return TCL_ERROR;
    break;
  case 5:
  case 6:
    if (Tcl_GetIntFromObj(interp, objv[3], o1) != TCL_OK) return TCL_ERROR;
    if (Tcl_GetIntFromObj(interp, objv[4], o2) != TCL_OK) return TCL_ERROR;
    if (argc == 6) {
      if (Tcl_GetIntFromObj(interp, objv[5], n) != TCL_OK) return TCL_ERROR;
    } else {
      *n = *n1;
    }
  }
  return TCL_OK;
}
static int _vector_zdot(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // check for usage
  float complex *b1;
  float complex *b2;
  int n1, n2, o1, o2, n;
  if (_setup(interp, argc, objv, &b1, &b2, &n1, &n2, &o1, &o2, &n) != TCL_OK) return TCL_ERROR;
  float complex z = _zdot(n1, b1, o1, n2, b2, o2, n);
    return fw_success_obj(interp, Tcl_NewListObj(2, (Tcl_Obj *[]){ Tcl_NewDoubleObj(crealf(z)), Tcl_NewDoubleObj(cimagf(z)), NULL }));
}
static int _vector_rdot(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // check for usage
  float complex *b1;
  float complex *b2;
  int n1, n2, o1, o2, n;
  if (_setup(interp, argc, objv, &b1, &b2, &n1, &n2, &o1, &o2, &n) != TCL_OK) return TCL_ERROR;
  return fw_success_obj(interp, Tcl_NewDoubleObj(_rdot(n1, b1, o1, n2, b2, o2, n)));
}
static int _vector_idot(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // check for usage
  float complex *b1;
  float complex *b2;
  int n1, n2, o1, o2, n;
  if (_setup(interp, argc, objv, &b1, &b2, &n1, &n2, &o1, &o2, &n) != TCL_OK) return TCL_ERROR;
  return fw_success_obj(interp, Tcl_NewDoubleObj(_idot(n1, b1, o1, n2, b2, o2, n)));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Vector_dot_Init(Tcl_Interp *interp) {
  if (framework_init(interp, "dsptcl::vector-dot", "1.0.0", "dsptcl::vector-zdot", _vector_zdot) != TCL_OK) return TCL_ERROR;
  Tcl_CreateObjCommand(interp, "dsptcl::vector-rdot", _vector_rdot, NULL, NULL);
  Tcl_CreateObjCommand(interp, "dsptcl::vector-idot", _vector_idot, NULL, NULL);
  return TCL_OK;
}
