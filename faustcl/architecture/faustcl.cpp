/************************************************************************
 IMPORTANT NOTE : this file contains two clearly delimited sections :
 the ARCHITECTURE section (in two parts) and the USER section. Each section
 is governed by its own copyright and license. Please check individually
 each section for license and copyright information.
 *************************************************************************/

/******************* BEGIN jack-tcltk.cpp ****************/
/************************************************************************
 FAUST Architecture File
 Copyright (C) 2003-2024 GRAME, Centre National de Creation Musicale
 ---------------------------------------------------------------------
 This Architecture section is free software; you can redistribute it
 and/or modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 3 of
 the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; If not, see <http://www.gnu.org/licenses/>.
 
 EXCEPTION : As a special exception, you may create a larger work
 that contains this FAUST architecture section and distribute
 that work under terms of your choice, so long as this FAUST
 architecture section is not modified.
 
 ************************************************************************
 ************************************************************************/

#include <libgen.h>
#include <stdlib.h>
#include <iostream>
#include <list>

#include "faust/dsp/timed-dsp.h"
#include "faust/dsp/one-sample-dsp.h"
#include "faust/dsp/poly-dsp.h"
//#include "faust/gui/FUI.h"
//#include "faust/gui/PrintUI.h"
#include "faust/misc.h"
//#include "faust/gui/PresetUI.h"
#include "faust/audio/jack-dsp.h"

//#ifdef OSCCTRL
//#include "faust/gui/OSCUI.h"
//static void osc_compute_callback(void* arg)
//{
//    static_cast<OSCUI*>(arg)->endBundle();
//}
//#endif

//#ifdef HTTPCTRL
//#include "faust/gui/httpdUI.h"
//#endif

//#if SOUNDFILE
//#include "faust/gui/SoundUI.h"
//#endif

// Always include this file, otherwise -nvoices only mode does not compile....
#include "faust/gui/MidiUI.h"

//#ifdef OCVCTRL
//#include "faust/gui/OCVUI.h"
//#endif

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

using namespace std;

#define FAUSTFLOAT float

#include TCL_INCLUDE_FILE	// include file generated from json

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <tcl8.6/tcl.h>

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
    // proc faustk::%s {w c} {
    //   ...
    // }
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
    // ttk::labelframe $w.$path
    // ttk::notebook
    appendLabel("openTabBox", label);
  }
  void openHorizontalBox(const char* label) {
    // ttk::labelframe
    // grid
    appendLabel("openHorizontalBox", label);
  }
  void openVerticalBox(const char* label) {
    // ttk::labelframe
    // grid
    appendLabel("openVerticalBox", label);
  }
  void closeBox() {
    // {}
    Tcl_Obj *objv[] = { Tcl_NewStringObj("closeBox", -1) };
    appendList(1, objv);
  } 
  // -- active widgets
  // ttk::button $w.%s -text %s
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

// two mysterious otherwise undefined symbols
list<GUI*> GUI::fGuiList;
ztimedmap GUI::gTimedZoneMap;

#ifdef __cplusplus
extern "C"
{
#endif

// the structure which defines the faust dsp instrument or effect
typedef struct {
  Tcl_Interp *interp;
  Tcl_Obj *class_name;
  Tcl_Obj *command_name;
  Tcl_Obj *rc_file_name;
  int nvoices;
  int midi_sync;
  int control;
  int group;
  dsp *DSP;
  jackaudio_midi *AUDIO;
  MidiUI* MIDI;
  Tcl_Obj *meta_dict;
  Tcl_Obj *ui_list;
#ifdef FILEUI
    FUI *finterface;
#endif
#ifdef PRESETUI
    PresetUI *pinterface;
#endif
  FAUSTFLOAT *zonePtrs[NZONES];
} _client_data_t;

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
    _client_data_t *cdata = (_client_data_t *)clientData;
    int opt;
    if (argc != 3) return _error_obj(interp, Tcl_ObjPrintf("usage: %s cget -option", Tcl_GetString(objv[0])));
    if (_optionLookup(interp, objv[2], &opt) != TCL_OK) return TCL_ERROR;
    return _success_obj(interp, Tcl_NewDoubleObj(*cdata->zonePtrs[opt]));
  }

  // configure command implementation
  static int _configure(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    _client_data_t *cdata = (_client_data_t *)clientData;
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
    _client_data_t *cdata = (_client_data_t *)clientData;  
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
    _client_data_t *cdata = (_client_data_t *)clientData;  
    if (cdata->MIDI) cdata->MIDI->stop();
    if (cdata->MIDI) delete cdata->MIDI;
    if (cdata->AUDIO) cdata->AUDIO->stop();
    // cdata->AUDIO->init(command_name, cdata->DSP) complement is in delete
    if (cdata->ui_list) Tcl_DecrRefCount(cdata->ui_list);
    if (cdata->meta_dict) Tcl_DecrRefCount(cdata->meta_dict);
    if (cdata->AUDIO) delete cdata->AUDIO;
    if (cdata->DSP) delete cdata->DSP;
    if (cdata->rc_file_name) Tcl_DecrRefCount(cdata->rc_file_name);
    if (cdata->command_name) Tcl_DecrRefCount(cdata->command_name);
    if (cdata->class_name) Tcl_DecrRefCount(cdata->class_name);
    Tcl_Free((char *)clientData);
  }

  static void _analyze(dsp *DSP, int *midi_sync, int *nvoices) {
    // midi_sync = some UI element specifies "midi:start" "midi:stop" "midi:clock" or "midi:timestamp"
    // nvoices = metadata options entry specifies [nvoices:<int>]
  }
  
  static int _getoption(Tcl_Interp *interp, int argc, Tcl_Obj * const *objv, const char *optname, int defaultvalue) {
    int optvalue;
    for (int i = 0; i+1 < argc; i += 1)
      if (strcmp(optname, Tcl_GetString(objv[i])) == 0)
	if (Tcl_GetIntFromObj(interp, objv[i+1], &optvalue) == TCL_OK)
	  return optvalue;
    return defaultvalue;
  }
  
  static int _dsperror(Tcl_Interp *interp, _client_data_t *cdata) {
    if (cdata->DSP == NULL) {
      _delete(cdata);
      _error_str(interp, "Faust DSP allocation failure");
      return 1;
    } else {
      return 0;
    }
  }

  // the factory command which builds instances faust dsp instruments or effects
  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    // test for insufficient arguments
    if (argc < 2 || (argc&1) != 0)
      return _error_obj(interp, Tcl_ObjPrintf("usage: %s name [-option value ...]", Tcl_GetString(objv[0])));

    // allocate command data
    _client_data_t *cdata = (_client_data_t *)Tcl_Alloc(sizeof(_client_data_t));
    if (cdata == NULL)
      return _error_str(interp, "memory allocation failure");

    // initialize command data
    memset(cdata, 0, sizeof(_client_data_t));
    cdata->midi_sync = false;
    cdata->control = true;
    cdata->nvoices = 4;
    cdata->interp = interp;
    Tcl_IncrRefCount((cdata->class_name = objv[0]));
    Tcl_IncrRefCount((cdata->command_name = objv[1]));
    Tcl_IncrRefCount((cdata->rc_file_name = Tcl_ObjPrintf("%s/.config/faustcl/%s", getenv("HOME"), Tcl_GetString(cdata->command_name))));

    // // //
    cdata->DSP = new mydsp();
    if (_dsperror(interp, cdata)) return TCL_ERROR;
    _analyze(cdata->DSP, &cdata->midi_sync, &cdata->nvoices);
    
    cdata->nvoices = _getoption(interp, argc, objv, "-nvoices", cdata->nvoices);
    cdata->control = _getoption(interp, argc, objv, "-control", cdata->control);
    cdata->group = _getoption(interp, argc, objv, "-group", 1);

    cout << "Started with " << cdata->nvoices << " voices\n";

    if (cdata->nvoices > 1) {
      // make a polyphonic synth
      cdata->DSP = new mydsp_poly(cdata->DSP, cdata->nvoices, cdata->control, cdata->group);
      if (_dsperror(interp, cdata)) return TCL_ERROR;
      // disabled because I can't find effect.h except in #includes in architecture files
      // add a common effect to the output
      // cdata->DSP = new dsp_sequencer(cdata->DSP, new effect());
      // if (_dsperror(interp, cdata)) return TCL_ERROR;
    }

    if (cdata->midi_sync) {
      // add midi timing support
      cdata->DSP = new timed_dsp(cdata->DSP);
      if (_dsperror(interp, cdata)) return TCL_ERROR;
    }

    // // // // 

    // build the TclTk interface
    Tcl_IncrRefCount((cdata->meta_dict = Tcl_NewDictObj())); 
    Tcl_IncrRefCount((cdata->ui_list = Tcl_NewListObj(0, NULL))); 

    cdata->DSP->metadata(new TcltkMeta(cdata->interp, cdata->meta_dict));
    cdata->DSP->buildUserInterface(new TcltkUI(cdata->interp, cdata->ui_list, cdata->zonePtrs));

    // // // // 

    // ignore these for a while, they need pointers allocated in _client_data_t
#ifdef FILEUI
    cdata->finterface = new FUI();
#endif
    //#ifdef PRESETUI
    //    cdata->pinterface = new PresetUI(cdata->interface, string(PRESETDIR) + string(Tcl_GetString(cdata->command_name)) + ((cdata->nvoices > 0) ? "_poly" : ""));
    //    cdata->DSP->buildUserInterface(cdata->pinterface);
    //#else
    //    DSP->buildUserInterface(interface);
    //    DSP->buildUserInterface(&finterface);
    //#endif
    
#ifdef HTTPCTRL
    httpdUI httpdinterface(name, DSP->getNumInputs(), DSP->getNumOutputs(), argc, argv);
    DSP->buildUserInterface(&httpdinterface);
    cout << "HTTPD is on" << endl;
#endif
    
#ifdef OCVCTRL
    OCVUI ocvinterface;
    DSP->buildUserInterface(&ocvinterface);
    cout << "OCVCTRL defined" << endl;
#endif
    // end of first ignore list
    
    cdata->AUDIO = new jackaudio_midi();
    if (cdata->AUDIO == NULL) { _delete(cdata); return _error_str(interp, "Faust audio allocation failure"); }

    // parse command line options
    if (argc > 2) {
      if (_configure(cdata, interp, argc, objv) != TCL_OK) {
	_delete(cdata);
	return TCL_ERROR;
      }
    }

    // initialize the dsp
    if ( ! cdata->AUDIO->init(Tcl_GetString(cdata->command_name), cdata->DSP)) {
      _delete(cdata);
      return _error_str(interp, "Unable to init audio");
    }

    // also, ignore these for the moment
#if SOUNDFILE
    SoundUI soundinterface("", audio.getSampleRate());
    DSP->buildUserInterface(&soundinterface);
#endif

#ifdef OSCCTRL
    OSCUI oscinterface(name, argc, argv);
    DSP->buildUserInterface(&oscinterface);
    cout << "OSC is on" << endl;
    audio.addControlCallback(osc_compute_callback, &oscinterface);
#endif
    
    cdata->MIDI = new MidiUI(cdata->AUDIO);
    if (cdata->MIDI == NULL) { _delete(cdata); return _error_str(interp, "Faust MIDI interface allocation failure"); }
    cout << "JACK MIDI is used" << endl;
    cdata->DSP->buildUserInterface(cdata->MIDI);
    cout << "MIDI is on" << endl;

  // construct midi and osc user interfaces

  // start the dsp running
  if ( ! cdata->AUDIO->start()) {
    _delete(cdata);
    return _error_str(interp,"Unable to start audio");
  }
  cout << "ins " << cdata->AUDIO->getNumInputs() << endl;
  cout << "outs " << cdata->AUDIO->getNumOutputs() << endl;
    
  // run user interfaces
#ifdef HTTPCTRL
  cdata->httpdinterface.run();
#endif
    
#ifdef OCVCTRL
  cdata->ocvinterface.run();
#endif
    
#ifdef OSCCTRL
  cdata->oscinterface.run();
#endif
    
  if (!cdata->MIDI->run()) {
    return _error_str(interp, "MidiUI run error");
  }
    
  // After the allocation of controllers
  // finterface.recallState(Tcl_GetString(cdata->rcfilename));
  
  // create Tcl command
  Tcl_CreateObjCommand(interp, Tcl_GetString(cdata->command_name), _command, (ClientData)cdata, _delete);

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
