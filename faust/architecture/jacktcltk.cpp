/******************* BEGIN jacktcl.cpp ****************/

// attempted to do this, with very gratifying size result,
// but "-midi 1" didn't make any midi noises, 
// and "-midi 1 -nvoices 12" crashed jackd.

#define USE_LIBJACKTCLTK 0

#if	USE_LIBJACKTCLTK

//#include <libgen.h>
//#include <stdlib.h>
//#include <iostream>
//#include <list>

//#include <stdio.h>
//#include <string.h>
//#include <stddef.h>

#include <tcl8.6/tcl.h>
#include "faust/gui/GUI.h"
#include "faust/gui/meta.h"
#include "faust/audio/jack-dsp.h"

using namespace std;

#else	// USE_LIBJACKTCLTK

#include "../architecture/libjacktcltk.cpp"

#endif	// USE_LIBJACKTCLTK
/******************************************************************************
 *******************************************************************************
 
 VECTOR INTRINSICS
 
 *******************************************************************************
 *******************************************************************************/

<<includeIntrinsic>>

/********************END ARCHITECTURE SECTION (part 1/2)****************/

/**************************BEGIN USER SECTION **************************/

<<includeclass>>

/***************************END USER SECTION ***************************/

/*******************BEGIN ARCHITECTURE SECTION (part 2/2)***************/

// these are class statics declared, but not defined, in GUI.h
// I believe their definition is pushed to here so that they
// can be resolved at shared library relocation time so that
// each user of a shared library gets its own copies of them.
// if not, then there may be no shared libraries.
list<GUI*> GUI::fGuiList;
ztimedmap GUI::gTimedZoneMap;

#ifdef __cplusplus
extern "C"
{
#endif
  extern int jacktcl_factory(dsp *DSP, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv);
  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return jacktcl_factory(new mydsp(), interp, argc, objv);
  }

  // the initialization function which installs the adapter factory
  // this is the only global symbol defined in the library
  int DLLEXPORT TCL_INIT_NAME(Tcl_Interp *interp) {
    // tcl stubs and tk stubs are needed for dynamic loading,
    // you must have this set as a compiler option
#ifdef USE_TCL_STUBS
    if (Tcl_InitStubs(interp, TCL_VERSION, 1) == NULL) {
      Tcl_SetResult(interp, "Tcl_InitStubs failed");
      return TCL_EROR;
    }
#endif
#ifdef USE_TK_STUBS
    if (Tk_InitStubs(interp, TCL_VERSION, 1) == NULL) {
      Tcl_SetResult(interp, "Tk_InitStubs failed");
      return TCL_EROR;
    }
#endif
    Tcl_PkgProvide(interp, TCL_PKG_NAME, TCL_PKG_VERSION);
    Tcl_CreateObjCommand(interp, TCL_CMD_NAME, _factory, NULL, NULL);
    return TCL_OK;
  }

#ifdef __cplusplus
}
#endif
