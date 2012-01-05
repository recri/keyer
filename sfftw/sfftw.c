#include "tcl.h"
#include "sfftw.h"
#include "srfftw.h"

static struct {
  char *name;
  int value;
} fftw_names[] = {
  /* flags for direction */
  "FFTW_FORWARD", -1,
  "FFTW_BACKWARD", 1,

  /* flags for the planner */
  "FFTW_ESTIMATE", 0,
  "FFTW_MEASURE",  1,
  "FFTW_OUT_OF_PLACE", 0,
  "FFTW_IN_PLACE", 8,
  "FFTW_USE_WISDOM", 16,
  "FFTW_THREADSAFE", 128		 /* guarantee plan is read-only so that the */
					 /* same plan can be used in parallel by */
					 /* multiple threads */
};

/* complex short float one dimensional transform */
static int Tcl_fftw_create_plan_specific(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {int int int pointer-var int pointer-var int} pointer */
  int n, dir, flags, ilength, istride, olength, ostride;
  fftw_complex *in, *out;
  fftw_plan plan;
  if (objc != 8) {
    Tcl_WrongNumArgs(interp, 1, objv, "n dir flags float-in stride-in float-out stride-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], &n) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &dir) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[3], &flags) != TCL_OK
      || (in = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[4], &ilength)) == NULL
      || ilength != sizeof(fftw_complex)*n
      || Tcl_GetIntFromObj(interp, objv[5], &istride) != TCL_OK
      || olength != sizeof(fftw_complex)*n
      || (out = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[6], &olength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[7], &ostride) != TCL_OK) {
    return TCL_ERROR;
  }
  plan = fftw_create_plan_specific(n, (fftw_direction)dir, flags, (fftw_complex *)in, istride, (fftw_complex *)out, ostride);
  Tcl_ResetResult(interp);
  Tcl_SetIntObj(Tcl_GetObjResult(interp), (int)plan);
  return TCL_OK;
}  
static int Tcl_fftw_create_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {int int int} pointer */
  int n, dir, flags;
  fftw_plan plan;
  if (objc != 4) {
    Tcl_WrongNumArgs(interp, 1, objv, "n dir flags");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], &n) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &dir) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[3], &flags) != TCL_OK) {
    return TCL_ERROR;
  }
  plan = fftw_create_plan(n, (fftw_direction)dir, flags);
  Tcl_ResetResult(interp);
  Tcl_SetIntObj(Tcl_GetObjResult(interp), (int)plan);
  return TCL_OK;
}
static int Tcl_fftw_print_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer} void */ 
  fftw_plan plan;
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK) {
    return TCL_ERROR;
  }
  fftw_print_plan(plan);
  return TCL_OK;
}
static int Tcl_fftw_destroy_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer} void */
  fftw_plan plan;
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK) {
    return TCL_ERROR;
  }
  fftw_destroy_plan(plan);
  return TCL_OK;
}
static int Tcl_fftw(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer int pointer-var int int pointer-var int int} void */
  fftw_plan plan;
  int howmany, ilength, istride, idist, olength, ostride, odist;
  fftw_complex *in, *out;
  if (objc != 9) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan howmany float-in stride-in dist-in float-out stride-out dist-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &howmany) != TCL_OK
      || (in = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[3], &ilength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[4], &istride) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[5], &idist) != TCL_OK
      || (out = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[6], &olength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[7], &ostride) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[8], &odist) != TCL_OK
      || ilength != olength
      || (ilength % sizeof(fftw_complex)) != 0) {
    return TCL_ERROR;
  }
  fftw(plan, howmany, in, istride, idist, out, ostride, odist);
  return TCL_OK;
}
static int Tcl_fftw_one(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer pointer-var pointer-var} void */
  fftw_plan plan;
  int ilength, olength;
  fftw_complex *in, *out;
  if (objc != 4) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan float-in float-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK
      || (in = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[2], &ilength)) == NULL
      || (out = (fftw_complex *)Tcl_GetByteArrayFromObj(objv[3], &olength)) == NULL
      || ilength != olength
      || (ilength % sizeof(fftw_complex)) != 0) {
    return TCL_ERROR;
  }
  fftw_one(plan, in, out);
  return TCL_OK;
}

/* wisdom management */
static int Tcl_fftw_forget_wisdom(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /*  {} void */
  if (objc != 1) {
    Tcl_WrongNumArgs(interp, 1, objv, "");
    return TCL_ERROR;
  }
  fftw_forget_wisdom();
  return TCL_OK;
}
static int Tcl_fftw_export_wisdom_to_string(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {} pointer-utf8 */
  char *wisdom;
  if (objc != 1) {
    Tcl_WrongNumArgs(interp, 1, objv, "");
    return TCL_ERROR;
  }
  wisdom = fftw_export_wisdom_to_string();
  Tcl_ResetResult(interp);
  Tcl_AppendResult(interp, wisdom, (char *)NULL);
  fftw_free(wisdom);
  return TCL_OK;
}
static int Tcl_fftw_import_wisdom_from_string(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /*  {pointer-utf8} */
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "wisdom");
    return TCL_ERROR;
  }
  if (fftw_import_wisdom_from_string(Tcl_GetString(objv[1])) != FFTW_SUCCESS) {
    return TCL_ERROR;
  }
  return TCL_OK;
}

/* real short float one dimensional transform */
static int Tcl_rfftw_create_plan_specific(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {int int int pointer-var int pointer-var int} pointer */
  int n, dir, flags, ilength, istride, olength, ostride;
  fftw_real *in, *out;
  fftw_plan plan;
  if (objc != 8) {
    Tcl_WrongNumArgs(interp, 1, objv, "n dir flags float-in stride-in float-out stride-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], &n) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &dir) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[3], &flags) != TCL_OK
      || (in = (fftw_real *)Tcl_GetByteArrayFromObj(objv[4], &ilength)) == NULL
      || ilength != sizeof(fftw_real)*n
      || Tcl_GetIntFromObj(interp, objv[5], &istride) != TCL_OK
      || olength != sizeof(fftw_real)*n
      || (out = (fftw_real *)Tcl_GetByteArrayFromObj(objv[6], &olength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[7], &ostride) != TCL_OK) {
    return TCL_ERROR;
  }
  plan = rfftw_create_plan_specific(n, (fftw_direction)dir, flags, (fftw_real *)in, istride, (fftw_real *)out, ostride);
  Tcl_ResetResult(interp);
  Tcl_SetIntObj(Tcl_GetObjResult(interp), (int)plan);
  return TCL_OK;
}
static int Tcl_rfftw_create_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /*  {int int int} pointer */
  int n, dir, flags;
  fftw_plan plan;
  if (objc != 4) {
    Tcl_WrongNumArgs(interp, 1, objv, "n dir flags");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], &n) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &dir) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[3], &flags) != TCL_OK) {
    return TCL_ERROR;
  }
  plan = rfftw_create_plan(n, (fftw_direction)dir, flags);
  Tcl_ResetResult(interp);
  Tcl_SetIntObj(Tcl_GetObjResult(interp), (int)plan);
  return TCL_OK;
}
static int Tcl_rfftw_print_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer} void */
  fftw_plan plan;
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK) {
    return TCL_ERROR;
  }
  rfftw_print_plan(plan);
  return TCL_OK;
}
static int Tcl_rfftw_destroy_plan(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer} void */
  fftw_plan plan;
  if (objc != 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK) {
    return TCL_ERROR;
  }
  rfftw_destroy_plan(plan);
  return TCL_OK;
}
static int Tcl_rfftw(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /*  {pointer int pointer-var int int pointer-var int int} void */
  fftw_plan plan;
  int howmany, ilength, istride, idist, olength, ostride, odist;
  fftw_real *in, *out;
  if (objc != 9) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan howmany float-in stride-in dist-in float-out stride-out dist-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[2], &howmany) != TCL_OK
      || (in = (fftw_real *)Tcl_GetByteArrayFromObj(objv[3], &ilength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[4], &istride) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[5], &idist) != TCL_OK
      || (out = (fftw_real *)Tcl_GetByteArrayFromObj(objv[6], &olength)) == NULL
      || Tcl_GetIntFromObj(interp, objv[7], &ostride) != TCL_OK
      || Tcl_GetIntFromObj(interp, objv[8], &odist) != TCL_OK
      || ilength != olength
      || (ilength % sizeof(fftw_real)) != 0) {
    return TCL_ERROR;
  }
  rfftw(plan, howmany, in, istride, idist, out, ostride, odist);
  return TCL_OK;
}
static int Tcl_rfftw_one(ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
  /* {pointer pointer-var pointer-var} void */
  fftw_plan plan;
  int ilength, olength;
  fftw_real *in, *out;
  if (objc != 4) {
    Tcl_WrongNumArgs(interp, 1, objv, "plan float-in float-out");
    return TCL_ERROR;
  }
  if (Tcl_GetIntFromObj(interp, objv[1], (int *)&plan) != TCL_OK) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "cannot parse plan", NULL);
    return TCL_ERROR;
  }
  if ((in = (fftw_real *)Tcl_GetByteArrayFromObj(objv[2], &ilength)) == NULL) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "cannot parse in", NULL);
    return TCL_ERROR;
  }
  if ((out = (fftw_real *)Tcl_GetByteArrayFromObj(objv[3], &olength)) == NULL) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "cannot parse out", NULL);
    return TCL_ERROR;
  }
  if (ilength != olength) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "ilength does not match olength", NULL);
    return TCL_ERROR;
  }
  if ((ilength % sizeof(fftw_real)) != 0) {
    Tcl_ResetResult(interp);
    Tcl_AppendResult(interp, "lengths are not multiples of scalar size", NULL);
    return TCL_ERROR;
  }
  rfftw_one(plan, in, out);
  return TCL_OK;
}

int Sfftw_Init(Tcl_Interp *interp) {
	
    if (Tcl_PkgProvide(interp, "Sfftw", "1.0") == TCL_ERROR) {
        return TCL_ERROR;
    }

    /*
     * Create sfftw commands.
     */
    Tcl_CreateObjCommand(interp, "fftw_create_plan_specific", Tcl_fftw_create_plan_specific, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_create_plan", Tcl_fftw_create_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_print_plan", Tcl_fftw_print_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_destroy_plan", Tcl_fftw_destroy_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw", Tcl_fftw, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_one", Tcl_fftw_one, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_forget_wisdom", Tcl_fftw_forget_wisdom, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_export_wisdom", Tcl_fftw_export_wisdom_to_string, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "fftw_import_wisdom", Tcl_fftw_import_wisdom_from_string, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw_create_plan_specific", Tcl_rfftw_create_plan_specific, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw_create_plan", Tcl_rfftw_create_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw_print_plan", Tcl_rfftw_print_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw_destroy_plan", Tcl_rfftw_destroy_plan, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw", Tcl_rfftw, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);
    Tcl_CreateObjCommand(interp, "rfftw_one", Tcl_rfftw_one, (ClientData) 0, (Tcl_CmdDeleteProc *) NULL);

    return TCL_OK;
}
