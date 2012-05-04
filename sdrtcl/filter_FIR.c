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
#define FRAMEWORK_USES_JACK 0

#include "../dspmath/filter_FIR.h"
#include "framework.h"

/*
** create FIR filter coefficients
*/
static enum { COMPLEX, REAL } ctype_t;
static char *ctypes[] = { "complex", "real", NULL };
static enum { BANDPASS, LOWPASS, HIGHPASS, BANDSTOP, HILBERT } ftype_t;
static char *ftypes[] = { "bandpass", "lowpass", "highpass", "bandstop", "hilbert", NULL };
  
static int _find_string_index(Tcl_Interp *interp, char *type, char **types, int *match) {
  for (int i = 0; types[i] != NULL; i += 1)
    if (strcmp(type, types[i]) == 0) {
      *match = i;
      return TCL_OK;
    }
  Tcl_AppendResult(interp, "no match for \"", type, "\", should be one of: ", NULL);
  for (int i = 0; types[i] != NULL; i += 1) {
    if (i > 0) {
      Tcl_AppendResult(interp, ", ", NULL);
      if (types[i+1] == NULL)
	Tcl_AppendResult(interp, "or ", NULL);
    }
    Tcl_AppendResult(interp, types[i], NULL);
  }
  return TCL_ERROR;
}
  
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc < 6)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s coeff-type filter-type sample-rate size ...", Tcl_GetString(objv[0])));
  int ctype, ftype, sample_rate, size;
  if (_find_string_index(interp, Tcl_GetString(objv[1]), ctypes, &ctype) != TCL_OK ||
      _find_string_index(interp, Tcl_GetString(objv[2]), ftypes, &ftype) != TCL_OK ||
      Tcl_GetIntFromObj(interp, objv[3], &sample_rate) != TCL_OK ||
      Tcl_GetIntFromObj(interp, objv[4], &size) != TCL_OK)
    return TCL_ERROR;
  double lo, hi, cutoff;
  switch (ftype) {
  case BANDPASS:
  case BANDSTOP:
  case HILBERT:
    if (argc != 7)
      return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s coeff-type filter-type sample-rate size low high", Tcl_GetString(objv[0])));
    if (Tcl_GetDoubleFromObj(interp, objv[5], &lo) != TCL_OK ||
	Tcl_GetDoubleFromObj(interp, objv[6], &hi) != TCL_OK)
      return TCL_ERROR;
    break;
  case LOWPASS:
  case HIGHPASS:
    if (argc != 6)
      return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s coeff-type filter-type sample-rate size cutoff", Tcl_GetString(objv[0])));
    if (Tcl_GetDoubleFromObj(interp, objv[5], &cutoff) != TCL_OK)
      return TCL_ERROR;
    break;
  default:
    return fw_error_str(interp, "unknown filter type!");
  }
  Tcl_Obj *result = Tcl_NewObj();
  if (ctype == REAL) {
    float *coeff = (float *)Tcl_SetByteArrayLength(result, size*sizeof(float));
    void *e;
    switch (ftype) {
    case BANDPASS: e = bandpass_real(lo, hi, sample_rate, size, coeff); break;
    case BANDSTOP: e = bandstop_real(lo, hi, sample_rate, size, coeff); break;
    case HILBERT: e = hilbert_real(lo, hi, sample_rate, size, coeff); break;
    case LOWPASS: e = lowpass_real(cutoff, sample_rate, size, coeff); break;
    case HIGHPASS: e = highpass_real(cutoff, sample_rate, size, coeff); break;
    }
    if (e != coeff) {
      Tcl_DecrRefCount(result);
      return fw_error_str(interp, e);
    }
  } else if (ctype == COMPLEX) {
    float complex *coeff = (float complex *)Tcl_SetByteArrayLength(result, size*sizeof(float complex));
    void *e;
    switch (ftype) {
    case BANDPASS: e = bandpass_complex(lo, hi, sample_rate, size, coeff); break;
    case BANDSTOP: e = bandstop_complex(lo, hi, sample_rate, size, coeff); break;
    case HILBERT: e = hilbert_complex(lo, hi, sample_rate, size, coeff); break;
    case LOWPASS: e = lowpass_complex(cutoff, sample_rate, size, coeff); break;
    case HIGHPASS: e = highpass_complex(cutoff, sample_rate, size, coeff); break;
    }
    if (e != coeff) {
      Tcl_DecrRefCount(result);
      return fw_error_str(interp, e);
    }
  } else {
    Tcl_DecrRefCount(result);
    return fw_error_str(interp, "unknown coefficient type!");
  }
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Filter_fir_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::filter-fir", "1.0.0", "sdrtcl::filter-fir", _command);
}

