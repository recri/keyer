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
** create an IQ corrector module which adaptively adjusts the phase and
** relative magnitudes of the I and Q channels to balance.
*/
#define FRAMEWORK_USES_JACK 0

#include "../dspmath/iq_correct.h"
#include "framework.h"

// the non-factory command which trains an iq balance filter
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  iq_correct_t iqb;
  if (argc != 5)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s mu wreal wimag samples", Tcl_GetString(objv[0])));
  double mu, wreal, wimag;
  int n_samples;
  float complex *samples;
  if (Tcl_GetDoubleFromObj(interp, objv[1], &mu) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[2], &wreal) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[3], &wimag) != TCL_OK) return TCL_ERROR;
  samples = (float complex *)Tcl_GetByteArrayFromObj(objv[4], &n_samples);
  if ((n_samples % sizeof(float complex)) != 0)
    return fw_error_obj(interp, Tcl_ObjPrintf("sample object is %d bytes, not a complex array", n_samples));
  iqb.mu = mu;
  iqb.w = wreal + I*wimag;
  for (n_samples /= sizeof(float complex); --n_samples >= 0; )
    iq_correct_process(&iqb, *samples++);
  return fw_success_obj(interp, Tcl_NewListObj(2, (Tcl_Obj *[]){ Tcl_NewDoubleObj(crealf(iqb.w)), Tcl_NewDoubleObj(cimagf(iqb.w)) }));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_correct_train_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::iq-correct-train", "1.0.0", "sdrtcl::iq-correct-train", _command);
}
