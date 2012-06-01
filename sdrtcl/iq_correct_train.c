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

// the non-factory command which simply applies an iq balance filter
static int _command0(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  iq_correct_t iqb;
  if (argc != 4)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s wreal wimag samples", Tcl_GetString(objv[0])));
  double wreal, wimag;
  int n_samples;
  float complex *samples;
  if (Tcl_GetDoubleFromObj(interp, objv[1], &wreal) != TCL_OK) return TCL_ERROR;
  if (Tcl_GetDoubleFromObj(interp, objv[2], &wimag) != TCL_OK) return TCL_ERROR;
  samples = (float complex *)Tcl_GetByteArrayFromObj(objv[3], &n_samples);
  if ((n_samples % sizeof(float complex)) != 0)
    return fw_error_obj(interp, Tcl_ObjPrintf("sample object is %d bytes, not a complex array", n_samples));
  n_samples /= sizeof(float complex);

  // do the computation in double precision to match the pure tcl version
  // also no reason to discard precision while training
  double complex w = wreal + I*wimag;
  int i;
  for (i = 0; i < n_samples; i += 1) {
    volatile double complex z1 = *samples + w * conjf(*samples);	// compute corrected sample
    samples += 1;						// next sample
  }
  return TCL_OK;
}
// the non-factory command which simply trains a specified iq balance filter
static int _command1(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
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
  int i;
  for (i = 0; i < n_samples; i += 1) {
    const double complex z1 = *samples + w * conjf(*samples);	// compute corrected sample
    w -= mu * z1 * z1;		// filter update: coefficients += -mu * error
    samples += 1;						// next sample
  }
  return fw_success_obj(interp, Tcl_NewListObj(2, (Tcl_Obj *[]){ Tcl_NewDoubleObj(creal(w)), Tcl_NewDoubleObj(cimag(w)) }));
}
// the non-factory command which trains an iq balance filter and gathers statistics
static int _command2(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
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
  double sum_r2 = 0;
  double sum_i2 = 0;
  int i;
  for (i = 0; i < n_samples; i += 1) {
    const double complex z1 = *samples + w * conjf(*samples);	// compute corrected sample
    w -= mu * z1 * z1;		// filter update: coefficients += -mu * error
    sum_w += w;
    sum_r2 += sqr(creal(w));
    sum_i2 += sqr(cimag(w));
    samples += 1;						// next sample
  }
  complex double mean_w = sum_w / i;
  double var_r = sum_r2 / i - sqr(creal(mean_w));
  double var_i = sum_i2 / i - sqr(cimag(mean_w));
  double dispersion_r = var_r / creal(mean_w);
  double dispersion_i = var_i / cimag(mean_w);
  return fw_success_obj(interp, Tcl_NewListObj(8, (Tcl_Obj *[]){
	Tcl_NewDoubleObj(creal(w)), Tcl_NewDoubleObj(cimag(w)),
	  Tcl_NewDoubleObj(creal(mean_w)), Tcl_NewDoubleObj(cimag(mean_w)),
	  Tcl_NewDoubleObj(var_r), Tcl_NewDoubleObj(var_i),
	  Tcl_NewDoubleObj(dispersion_r), Tcl_NewDoubleObj(dispersion_i) }));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Iq_correct_train_Init(Tcl_Interp *interp) {
  if (framework_init(interp, "sdrtcl::iq-correct-train", "1.0.0", "sdrtcl::iq-correct-train0", _command0) != TCL_OK ||
      framework_init(interp, "sdrtcl::iq-correct-train", "1.0.0", "sdrtcl::iq-correct-train1", _command1) != TCL_OK ||
      framework_init(interp, "sdrtcl::iq-correct-train", "1.0.0", "sdrtcl::iq-correct-train2", _command2) != TCL_OK)
    return TCL_ERROR;
  return TCL_OK;
}
