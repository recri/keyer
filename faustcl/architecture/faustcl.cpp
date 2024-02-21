
<<includeIntrinsic>>

#include "faust/misc.h"
#include "faust/gui/UI.h"
#include "faust/audio/jack-dsp.h"

#include <stdio.h>
#include <string.h>
#include <stddef.h>

#include <tcl8.6/tcl.h>

#define FAUSTFLOAT float

#include TCL_INCLUDE_FILE	// include file generated from json

// Meta stores metadata as a tcl dictionary;
struct TcltkMeta : public Meta {
  Tcl_Interp *interp;
  Tcl_Obj *dict;

  TcltkMeta(Tcl_Interp *interp, Tcl_Obj *dict) : interp(interp), dict(dict) {}

  void declare (const char* key, const char* value) {
    Tcl_DictObjPut(interp, dict, Tcl_NewStringObj(key, -1), Tcl_NewStringObj(value, -1));
  }
};

struct Soundfile {};

struct TcltkUI : public UI  {
  Tcl_Interp *interp;
  Tcl_Obj *ui_list;
  FAUSTFLOAT **zonePtrs;
  int nzones;

  TcltkUI(Tcl_Interp *interp, Tcl_Obj *ui_list, FAUSTFLOAT **zonePtrs)
    : interp(interp), ui_list(ui_list), zonePtrs(zonePtrs) {
    nzones = 0;
  }

  void appendList(int argc, Tcl_Obj *objv[]) {
    Tcl_ListObjAppendElement(interp, ui_list, Tcl_NewListObj(argc, objv));
  }
  void appendLabel(const char *type, const char *label) {
    Tcl_Obj *objv[] = { Tcl_NewStringObj(type, -1), Tcl_NewStringObj(label, -1) };
    appendList(2, objv);
  }
  void appendLabelZone(const char *type, const char *label, FAUSTFLOAT *zone) {
    zonePtrs[nzones] = zone;
    Tcl_Obj *objv[] = {
      Tcl_NewStringObj(type, -1),
      Tcl_NewStringObj(label, -1),
      Tcl_NewByteArrayObj((const unsigned char *)zone, sizeof(FAUSTFLOAT)),
      Tcl_NewIntObj(nzones++)
    };
    appendList(4, objv);
  }
  void appendLabelZoneIMMS(const char *type, const char *label, FAUSTFLOAT *zone,
			   FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    zonePtrs[nzones] = zone;
    Tcl_Obj *objv[] = { 
      Tcl_NewStringObj(type, -1), 
      Tcl_NewStringObj(label, -1), 
      Tcl_NewByteArrayObj((const unsigned char *)zone, sizeof(FAUSTFLOAT)),
      Tcl_NewIntObj(nzones++),
      Tcl_NewDoubleObj(init),
      Tcl_NewDoubleObj(min),
      Tcl_NewDoubleObj(max),
      Tcl_NewDoubleObj(step)
    };
    appendList(8, objv);
  }
  void appendLabelZoneMM(const char *type, const char *label, FAUSTFLOAT *zone, 
		    FAUSTFLOAT min, FAUSTFLOAT max) {
    zonePtrs[nzones] = zone;
    Tcl_Obj *objv[] = { 
      Tcl_NewStringObj(type, -1), 
      Tcl_NewStringObj(label, -1),
      Tcl_NewByteArrayObj((const unsigned char *)zone, sizeof(FAUSTFLOAT)),
      Tcl_NewIntObj(nzones++),
      Tcl_NewDoubleObj(min), 
      Tcl_NewDoubleObj(max)
    };
    appendList(6, objv);
  }
  // -- widget layouts
  void openTabBox(const char* label) {
    appendLabel("openTabBox", label);
  }
  void openHorizontalBox(const char* label) {
    appendLabel("openHorizontalBox", label);
  }
  void openVerticalBox(const char* label) {
    appendLabel("openVerticalBox", label);
  }
  void closeBox() {
    Tcl_Obj *objv[] = { Tcl_NewStringObj("closeBox", -1) };
    appendList(1, objv);
  } 
  // -- active widgets
  void addButton(const char* label, FAUSTFLOAT* zone) {
    appendLabelZone("addButton", label, zone);
  }
  void addCheckButton(const char* label, FAUSTFLOAT* zone) {
    appendLabelZone("addCheckButton", label, zone);
  }
  void addVerticalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendLabelZoneIMMS("addVerticalSlider", label, zone, init, min, max, step);
  }
  void addHorizontalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendLabelZoneIMMS("addHorizontalSlider", label, zone, init, min, max, step);;
  }
  void addNumEntry(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendLabelZoneIMMS("addNumEntry", label, zone, init, min, max, step);;
  }
  // -- passive widgets
  void addHorizontalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT min, FAUSTFLOAT max) {
    appendLabelZoneMM("addHorizontalBargraph", label, zone, min, max);
  }
  void addVerticalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT min, FAUSTFLOAT max) {
    appendLabelZoneMM("addVerticalBargraph", label, zone, min, max);
  }
  // -- soundfiles
  void addSoundfile(const char* label, const char* filename, Soundfile** sf_zone) { }
  // -- metadata declarations
  void declare(FAUSTFLOAT* zone, const char* key, const char* val) { }
};

<<includeclass>>

#ifdef __cplusplus
extern "C"
{
#endif

// the structure which defines the faust dsp instrument or effect
typedef struct {
  Tcl_Interp *interp;
  Tcl_Obj *class_name;
  Tcl_Obj *command_name;
  dsp *DSP;
  audio *AUDIO;
  // MapUI *ui_map;
  Tcl_Obj *meta_dict;
  Tcl_Obj *ui_list;
  FAUSTFLOAT *zonePtrs[NZONES];
} _data;			// FIX.ME rewrite as _client_data_t

/*
** common error/success return with dyanamic or static interp result
*/
static int _result_obj(Tcl_Interp *interp, Tcl_Obj *obj, int ret) {
  Tcl_SetObjResult(interp, obj);
  return ret;
}
static int _result_str(Tcl_Interp *interp, const char *str, int ret) {
  Tcl_SetObjResult(interp, Tcl_NewStringObj(str, -1));
  return ret;
}
static int _error_obj(Tcl_Interp *interp, Tcl_Obj *obj) {
  return _result_obj(interp, obj, TCL_ERROR);
}
static int _error_str(Tcl_Interp *interp, const char *str) {
  return _result_str(interp, str, TCL_ERROR);
}
static int _success_obj(Tcl_Interp *interp, Tcl_Obj *obj) {
  return _result_obj(interp, obj, TCL_OK);
}
static int _success_str(Tcl_Interp *interp, const char *str) {
  return _result_str(interp, str, TCL_OK);
}

// option helpers
int _optionLookup(Tcl_Interp *interp, Tcl_Obj *obj, int *valp) {
  char *str = Tcl_GetString(obj);
  for (int opt = 0; opt < NZONES; opt += 1) {
    if (strcmp(_options[opt].shortname, str+1) == 0 ||
	strcmp(_options[opt].address, str+1) == 0) {
      *valp = opt;
      return TCL_OK;
    }
  }
  Tcl_ResetResult(interp);
  return _error_obj(interp, Tcl_ObjPrintf("invalid option %s", str));
}

int _getFloatFromObj(Tcl_Interp *interp, Tcl_Obj *obj, float *valp) {
  double double_val;
  if (Tcl_GetDoubleFromObj(interp, obj, &double_val) == TCL_OK) {
    *valp = double_val;
    return TCL_OK;
  }
  return TCL_ERROR;
}
	
// cget command implementation
static int _cget(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _data *cdata = (_data *)clientData;
  int opt;
  if (argc != 3) return _error_obj(interp, Tcl_ObjPrintf("usage: %s cget -option", Tcl_GetString(objv[0])));
  if (_optionLookup(interp, objv[2], &opt) != TCL_OK) return TCL_ERROR;
  return _success_obj(interp, Tcl_NewDoubleObj(*cdata->zonePtrs[opt]));
}

// configure command implementation
static int _configure(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _data *cdata = (_data *)clientData;
  if (argc < 2 || (argc&1) != 0)
    return _error_obj(interp, Tcl_ObjPrintf("usage: %s configure [-option value ...]", Tcl_GetString(objv[0])));
  if (argc == 2) {
    Tcl_ResetResult(interp);
    for (int i = 0; i < NZONES; i += 1) {
      Tcl_AppendResult(interp, i==0?"-":" -", _options[i].shortname, " ", Tcl_GetString(Tcl_NewDoubleObj(*cdata->zonePtrs[i])), NULL);
    }
    return TCL_OK;
  } else if ((argc & 1) != 0) {
    return _error_str(interp, "usage: %s configure [option value ...]");
  } else {
    for (int a = 2; a < argc; a += 2) {
      int opt;
      FAUSTFLOAT val;
      if (_optionLookup(interp, objv[a], &opt) == TCL_ERROR) return TCL_ERROR;
      if (_getFloatFromObj(interp, objv[a+1], &val) == TCL_ERROR) return TCL_ERROR;
      *cdata->zonePtrs[opt] = val;
    }
    return TCL_OK;
  }
}

// the command which implements instances of faust dsp instruments of effects
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _data *cdata = (_data *)clientData;  
  if (argc >= 2) {
    const char *method = Tcl_GetString(objv[1]);
    if (strcmp(method, "configure") == 0) return _configure(clientData, interp, argc, objv);
    if (strcmp(method, "cget") == 0) return _cget(clientData, interp, argc, objv);
    if (strcmp(method, "meta") == 0) return _success_obj(interp, cdata->meta_dict);
    if (strcmp(method, "ui") == 0) return _success_obj(interp, cdata->ui_list);
  }
  return _error_obj(interp, Tcl_ObjPrintf("usage: %s name configure|cget|meta|ui [...]", Tcl_GetString(objv[0])));
}

// the command which cleans up
static void _delete(ClientData clientData) {
  _data *cdata = (_data *)clientData;  
  // FIX.ME - cleanly delete in the clientData
}

// the factory command which builds instances faust dsp instruments or effects
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // test for insufficient arguments
  if (argc < 2 || (argc&1) != 0)
    return _error_obj(interp, Tcl_ObjPrintf("usage: %s name [-option value ...]", Tcl_GetString(objv[0])));

  // allocate command data
  _data *cdata = (_data *)Tcl_Alloc(sizeof(_data));
  if (cdata == NULL)
    return _error_str(interp, "memory allocation failure");

  // grab some string values
  const char *class_name = Tcl_GetString(objv[0]);
  const char *command_name = Tcl_GetString(objv[1]);

  // initialize command data
  memset(cdata, 0, sizeof(_data));
  cdata->interp = interp;
  cdata->class_name = objv[0]; 
  cdata->command_name = objv[1];
  cdata->DSP = new mydsp();
#ifdef MIDICTRL
  cdata->AUDIO = new jackaudio_midi();
#else
  cdata->AUDIO = new jackaudio();
#endif
  //  cdata->ui_map = new MapUI();
  cdata->meta_dict = Tcl_NewDictObj(); 
  cdata->ui_list = Tcl_NewListObj(0, NULL); 

  // persist tcl objects
  Tcl_IncrRefCount(cdata->class_name);
  Tcl_IncrRefCount(cdata->command_name);
  Tcl_IncrRefCount(cdata->meta_dict);
  Tcl_IncrRefCount(cdata->ui_list);

  // check for allocation errors
  if (cdata->DSP == NULL) { _delete(cdata); return _error_str(interp, "Faust DSP allocation failure"); }
  if (cdata->AUDIO == NULL) { _delete(cdata); return _error_str(interp, "Faust audio allocation failure"); }
  //   if (cdata->ui_map == NULL) { _delete(cdata); return _error_str(interp, "Faust MapUI allocation failure"); }

  // load the ui data
  // cdata->DSP->buildUserInterface(cdata->ui_map);
  cdata->DSP->metadata(new TcltkMeta(cdata->interp, cdata->meta_dict));
  cdata->DSP->buildUserInterface(new TcltkUI(cdata->interp, cdata->ui_list, cdata->zonePtrs));

  // parse command line options
  if (argc > 2) {
    if (_configure(cdata, interp, argc, objv) != TCL_OK) {
      _delete(cdata);
      return TCL_ERROR;
    }
  }

  // initialize the dsp
  if ( ! cdata->AUDIO->init(command_name, cdata->DSP)) {
    _delete(cdata);
    return _error_str(interp, "Unable to init audio");
  }

  // construct midi and osc user interfaces

  // start the dsp running
  if ( ! cdata->AUDIO->start()) {
    _delete(cdata);
    return _error_str(interp,"Unable to start audio");
  }
    
  // run user interfaces
  
  // create Tcl command
  Tcl_CreateObjCommand(interp, command_name, _command, (ClientData)cdata, _delete);

  Tcl_SetObjResult(interp, objv[1]);

  return TCL_OK;
}

// the initialization function which installs the adapter factory
// this is the only global symbol defined in the library
int DLLEXPORT TCL_INIT_NAME(Tcl_Interp *interp) {
// tcl stubs and tk stubs are needed for dynamic loading,
// you must have this set as a compiler option
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, TCL_VERSION, 1) == NULL)
    return _error_str(interp, "Tcl_InitStubs failed");
#endif
#ifdef USE_TK_STUBS
  if (Tk_InitStubs(interp, TCL_VERSION, 1) == NULL)
    return _error_str(interp,"Tk_InitStubs failed");
#endif
  Tcl_PkgProvide(interp, TCL_PKG_NAME, TCL_PKG_VERSION);
  Tcl_CreateObjCommand(interp, TCL_CMD_NAME, _factory, NULL, NULL);
  return TCL_OK;
}

#ifdef __cplusplus
}
#endif
