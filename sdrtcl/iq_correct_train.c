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
  n_samples /= sizeof(float complex);

  // do the computation in double precision to match the pure tcl version
  // also no reason to discard precision while training
  double complex w = wreal + I*wimag;
  double complex sum_w = 0;
  double complex mean_w = 0;
  double sum_mag = 0;
  double sum_mag2 = 0;
  double mean_mag = 0;
  double var_mag = 0;
  double dispersion_mag = 0;
  int i;
  for (i = 0; i < n_samples; i += 1) {
    const double complex z1 = *samples + w * conjf(*samples);	// compute corrected sample
    const double complex w_new = w - mu * z1 * z1;		// filter update: coefficients += -mu * error
    if (isnan(creal(w_new)) || isnan(cimag(w_new)) || cabs(w_new) > 1) break;
    w = w_new;
    sum_w += w;
    double mag2 = cabs2(w);
    sum_mag2 += mag2;
    sum_mag += sqrt(mag2);
    samples += 1;						// next sample
  }
  if (i > 0) {
    mean_w = sum_w / i;
    mean_mag = sum_mag / i;
    var_mag = sum_mag2 / i - mean_mag * mean_mag;
    dispersion_mag = var_mag / mean_mag;
  } else {
    mean_w = w;
    mean_mag = cabs(w);
    var_mag = 0;
    dispersion_mag = 0;
  }
  return fw_success_obj(interp, Tcl_NewListObj(8, (Tcl_Obj *[]){
	Tcl_NewDoubleObj(creal(w)), Tcl_NewDoubleObj(cimag(w)),
	  Tcl_NewDoubleObj(creal(mean_w)), Tcl_NewDoubleObj(cimag(mean_w)),
	  Tcl_NewDoubleObj(mean_mag), Tcl_NewDoubleObj(var_mag), Tcl_NewDoubleObj(dispersion_mag),
	  Tcl_NewIntObj(i) }));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_correct_train_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::iq-correct-train", "1.0.0", "sdrtcl::iq-correct-train", _command);
}
