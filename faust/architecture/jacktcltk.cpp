/******************* BEGIN libjacktcl.cpp ****************/
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

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <ctype.h>
#include <tcl8.6/tcl.h>

// UI inclusions

//#define FILEUI 1	// be prepared to maintain rc files per component if -file true
//#define PRESETUI 1	// be prepared to maintain preset files per component if -preset true
//#define OSCCTRL 1	// be prepared to implement an OSC controller if -osc true
//#define HTTPCTRL 1	// be prepared to implement an http controller if -httpd true
//#define SOUNDFILE 1	// be prepared to implement a sound file UI if -soundfile true
#define MIDICTRL 1	// always be prepared to implement a MIDI controller if -midi tue
//#define OCVCTRL 1	// be prepared to implement an OCV controller if -ocv true

// polyphony

//#define POLY2 1	// be prepared to implement polyphony if -poly true
//#define EFFECT 1	// be prepared for common polyphony effect if -effect auto|effect.dsp

#include "faust/dsp/timed-dsp.h"
#include "faust/dsp/one-sample-dsp.h"

// UI includes, preserving order of #define's
#ifdef FILEUI
#include "faust/gui/FUI.h"
#endif

#include "faust/misc.h"

#ifdef PRESETUI
#include "faust/gui/PresetUI.h"
#endif
#include "faust/audio/jack-dsp.h"

#ifdef OSCCTRL
#include "faust/gui/OSCUI.h"
static void osc_compute_callback(void* arg)
{
    static_cast<OSCUI*>(arg)->endBundle();
}
#endif

#ifdef HTTPCTRL
#include "faust/gui/httpdUI.h"
#endif

#ifdef SOUNDFILE
#include "faust/gui/SoundUI.h"
#else
struct Soundfile {};
#endif

// Always include this file, otherwise -nvoices only mode does not compile....
#include "faust/gui/MidiUI.h"

#ifdef OCVCTRL
#include "faust/gui/OCVUI.h"
#endif

#include "faust/gui/MapUI.h"	// map ui used in TclTkGui

// polyphony
#include "faust/dsp/poly-dsp.h"

#ifdef POLY2
#include "faust/dsp/dsp-combiner.h"
#endif

using namespace std;

// #define FAUSTFLOAT float  // FIX.ME delete

// TclTkMeta stores metadata as a tcl dictionary;
struct TclTkMeta : public Meta {
  Tcl_Interp *interp;
  Tcl_Obj *dict;

  TclTkMeta(Tcl_Interp *interp, Tcl_Obj *dict) : interp(interp), dict(dict) { }

  void declare (const char* key, const char* value) {
    Tcl_DictObjPut(interp, dict, Tcl_NewStringObj(key, -1), Tcl_NewStringObj(value, -1));
  }

};

// TclTkGUI produces a string to be evaluated which defines
// a Tcl proc %s {w cmd} { ... } which builds a tk
// interface for $cmd in the window $w

struct TclTkGUI : public GUI  {
  Tcl_Interp *interp;
  Tcl_Obj *ui_list, *command_name;
  dsp *DSP;
  MapUI mapui;

public:
  TclTkGUI(Tcl_Interp *interp, Tcl_Obj *ui_list, Tcl_Obj *command_name, dsp *DSP) :
    interp(interp), ui_list(ui_list), command_name(command_name), DSP(DSP) {
    DSP->buildUserInterface(&mapui);
  }

  // used for map zoneptr to shortName, actually maps shortName to zonePtr.
  // used by configure for constructing all parameter mappings
  std::map<std::string, FAUSTFLOAT*>& getShortnameMap() { return mapui.getShortnameMap(); }

  // used to find zonePtr from shortName, address, or label
  // since I only use shortName, could be replaced by getShortNameMap()
  FAUSTFLOAT* getParamZone(const std::string& str) { return mapui.getParamZone(str); }

protected:
  // find the short name that identifies the zone
  const char *findShortName(FAUSTFLOAT *zone) {
    for (const auto& it : getShortnameMap()) {
      if (it.second == zone)
	return it.first.c_str();
    }
    return "";
  }

  // build a path from the stack of labels stored
  std::string buildWindowPath(const char *label) {
    std::string slashes = mapui.buildPath(label);
    std::string dots = "";
    for (auto &c : slashes)
      dots += (c == '/' ? '.' : isupper(c) ? tolower(c) : c);
    return dots;
  }
  
  // find the short name for an option
  std::string buildShortName(const char *label) { return mapui.buildShortname(label); }
  
  // push a label
  bool pushLabel(const char *label) { return mapui.pushLabel(label); }

  // pop a label
  bool popLabel() { return mapui.popLabel(); }
  
  // add to the code
  void appendCode(Tcl_Obj *lineOfCode) {
    Tcl_ListObjAppendElement(interp, ui_list, lineOfCode);
  }

  void appendPrefix() {
    appendCode(Tcl_ObjPrintf("proc %s {w cmd} {", Tcl_GetString(command_name)));
    appendCode(Tcl_NewStringObj("  set meta [dict create]", -1));
  }

  void appendSuffix() {
    appendCode(Tcl_NewStringObj("}", -1));
  }
  
  // append a layout item
  void appendLayout(const char *type, const char *label) {
    const std::string path = buildWindowPath(label);
    if (pushLabel(label))
      appendPrefix();
    appendCode(Tcl_ObjPrintf("  %s $w%s -label %s", type, path.c_str(), label));
  }

  // mark the end of a layout item
  void appendEndLayout(void) {
    if (popLabel())
      appendSuffix();
  }
  
  // append a button or checkbutton
  void appendButton(const char *type, const char *label, FAUSTFLOAT *zone) {
    const std::string path = buildWindowPath(label);
    const std::string option = buildShortName(label);
    // printf("path %s, option %s, label %s, zone %lud\n", path.c_str(), option.c_str(), label, (unsigned long)zone);
    appendCode(Tcl_ObjPrintf("  %s $w%s -label %s -command $cmd -option -%s", type, path.c_str(), label, option.c_str()));
  }
  
  // append a slider or a nentry
  void appendSlider(const char *type, const char *label, FAUSTFLOAT *zone, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT init, FAUSTFLOAT step) {
    const std::string path = buildWindowPath(label);
    const std::string option = buildShortName(label);
    // printf("path %s, option %s, label %s, zone %lud\n", path.c_str(), option.c_str(), label, (unsigned long)zone);
    appendCode(Tcl_ObjPrintf("  %s $w%s -label %s -command $cmd -option -%s -min %f -max %f -init %f -step %f",
			     type, path.c_str(), label, option.c_str(), min, max, init, step));
  }
  
  // append a bargraph
  void appendBargraph(const char *type, const char *label, FAUSTFLOAT *zone, FAUSTFLOAT min, FAUSTFLOAT max) {
    const std::string path = buildWindowPath(label);
    const std::string option = buildShortName(label);
    // printf("path %s, option %s, label %s, zone %lud\n", path.c_str(), option.c_str(), label, (unsigned long)zone);
    appendCode(Tcl_ObjPrintf("  %s $w%s -label %s -command $cmd -option -%s -min %f -max %f",
			     type, path.c_str(), label, option.c_str(), min, max));
  }

  // append a declaration
  void appendDeclare(FAUSTFLOAT *zone, const char *key, const char *value) {
    const char *option = findShortName(zone);
    appendCode(Tcl_ObjPrintf("  dict set meta -%s %s {%s}", option, key, value));
  }
  
public:
  // -- layouts widget
  void openTabBox(const char* label) { appendLayout("tgroup", label); }
  void openHorizontalBox(const char* label) { appendLayout("hgroup", label); }
  void openVerticalBox(const char* label) { appendLayout("vgroup", label); }
  void closeBox() { appendEndLayout(); }

  // -- active widgets
  void addButton(const char* label, FAUSTFLOAT* zone) { appendButton("button", label, zone); }
  void addCheckButton(const char* label, FAUSTFLOAT* zone) { appendButton("checkbutton", label, zone); }
  void addVerticalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendSlider("vslider", label, zone, min, max, init, step);
  }
  void addHorizontalSlider(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendSlider("hslider", label, zone, min, max, init, step);
  }
  void addNumEntry(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max, FAUSTFLOAT step) {
    appendSlider("nentry", label, zone, min, max, init, step);
  }
  // -- passive widgets
  void addHorizontalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT min, FAUSTFLOAT max) {
    appendBargraph("hbargraph", label, zone, min, max);
  }
  void addVerticalBargraph(const char* label, FAUSTFLOAT* zone, FAUSTFLOAT min, FAUSTFLOAT max) {
    appendBargraph("vbargraph", label, zone, min, max);
  }
  // -- soundfiles - haven't found an example of this to copy, yet
  void addSoundfile(const char* label, const char* filename, Soundfile** sf_zone) { }
  // -- metadata declarations
  void declare(FAUSTFLOAT* zone, const char* key, const char* val) { 
    appendDeclare(zone, key, val);
  }
};

// the structure which defines the faust dsp instrument or effect
// this is all the information maintained by the _factory().
struct _client_data_t {
  dsp *DSP;
  Tcl_Interp *interp;
  int argc;			// only valid until _factory() returns;
  Tcl_Obj *const *objv;		// only valid until _factory() returns;
  Tcl_Obj *class_name;
  Tcl_Obj *command_name;
  bool *arg_used;		// allocated to argc values, false
  const char **argv;		// allocated with argc values, Tcl_GetString(objv[i])
  int nvoices;
  bool midi_sync;
  bool control;
  bool group;
#ifdef FILEUI
  Tcl_Obj *rc_file_name;
  FUI *finterface;
#endif
#ifdef PRESETUI
  Tcl_Obj *preset_dir;
  PresetUI *pinterface;
#endif
#ifdef OSCCTRL
  OSCUI *oscinterface;
#endif
#ifdef HTTPCTRL
  httpdUI *httpdinterface;
#endif
#ifdef SOUNDFILE
  SoundUI *soundinterface;
#endif
#ifdef MIDICTRL
  bool opt_midi;
  MidiUI* midiinterface;
#endif
#ifdef OCVCTRL
  OCVUI *ocvinterface;
#endif
#ifdef MIDICTRL
  jackaudio_midi *AUDIO;
#else
  jackaudio *AUDIO;
#endif
  Tcl_Obj *meta_dict;
  Tcl_Obj *ui_list;
  TclTkGUI *interface;

  // create a client_data_t
  _client_data_t(dsp *DSP, Tcl_Interp *interp, int argc, Tcl_Obj *const*objv) :
    DSP(DSP), interp(interp), argc(argc), objv(objv),
    class_name(nullptr), command_name(nullptr), arg_used(nullptr), argv(nullptr),
    nvoices(0), midi_sync(false), control(false), group(false),
#ifdef FILEUI
    rc_file_name(nullptr), finterface(nullptr),
#endif
#ifdef PRESETUI
    preset_dir(nullptr), pinterface(nullptr),
#endif
#ifdef OSCCTRL
    oscinterface(nullptr),
#endif
#ifdef HTTPCTRL
    httpdinterface(nullptr),
#endif
#ifdef SOUNDFILE
    soundinterface(nullptr),
#endif
#ifdef MIDICTRL
    opt_midi(false), midiinterface(nullptr),
#endif
#ifdef OCVCTRL
    ocvinterface(nullptr),
#endif
    AUDIO(nullptr), meta_dict(nullptr), ui_list(nullptr), interface(nullptr)
  {
    _init_for_argc();
  }

  void _init_for_argc(void) {
    if (arg_used) delete arg_used;
    if (argv) delete argv;
    arg_used = new bool[argc];
    argv = new const char *[argc];
    for (int i = 0; i < argc; i += 1) {
      arg_used[i] = false;
      argv[i] = Tcl_GetString(objv[i]);
    }
  }

  // and clean it up
  ~_client_data_t() {
#ifdef FILEUI
    if (finterface) { finterface->saveState(Tcl_GetString(rc_file_name)); delete finterface; }
    if (rc_file_name) Tcl_DecrRefCount(rc_file_name);
#endif
#ifdef MIDICTRL
    if (midiinterface) { midiinterface->stop(); delete midiinterface; }
#endif    
#ifdef OSCCTRL
    if (oscinterface) { oscinterface->stop(); delete oscinterface; }
#endif
#ifdef OCVCTRL
    if (ocvinterface) { ocvinterface->stop(); delete ocvinterface; }
#endif
#ifdef HTTPCTRL
    if (httpdinterface) { httpdinterface->stop(); delete httpdinterface; }
#endif
    // if (interface) { interface->stop(); delete interface; }
    if (AUDIO) { AUDIO->stop(); delete AUDIO; }
    // AUDIO->init(command_name, DSP) complement is in delete
#ifdef SOUNDFILE
    if (soundinterface) delete soundinterface;
#endif
#ifdef PRESETUI
    if (presetui) delete presetui:
    if (preset_dir) Tcl_DecrRefCount(preset_dir);
#endif    
    if (ui_list) Tcl_DecrRefCount(ui_list);
    if (meta_dict) Tcl_DecrRefCount(meta_dict);
    if (command_name) Tcl_DecrRefCount(command_name);
    if (class_name) Tcl_DecrRefCount(class_name);
    if (arg_used) delete arg_used;
    if (argv) delete argv;
    if (DSP) delete DSP;
  }
    
  /*
  ** common error/success return with dyanamic or static interp result
  */
  int _result_obj(Tcl_Obj *obj, int ret) {
    Tcl_SetObjResult(interp, obj);
    return ret;
  }
  int _result_str(const char *str, int ret) {
    Tcl_SetObjResult(interp, Tcl_NewStringObj(str, -1));
    return ret;
  }
  int _error_obj(Tcl_Obj *obj) { return _result_obj(obj, TCL_ERROR); }
  int _error_str(const char *str) { return _result_str(str, TCL_ERROR); }
  int _success_obj(Tcl_Obj *obj) { return _result_obj(obj, TCL_OK); }
  int _success_str(const char *str) { return _result_str(str, TCL_OK); }

  // option helpers
  int _optionLookup(Tcl_Obj *obj, FAUSTFLOAT **valp) {
    *valp = interface->getParamZone(Tcl_GetString(obj)+1);
    // printf("option %s, zone %lud\n", Tcl_GetString(obj), (unsigned long)*valp);
    return (*valp != NULL) ? TCL_OK :
      _error_obj(Tcl_ObjPrintf("invalid option \"%s\".", Tcl_GetString(obj)));
  }

  int _getFloatFromObj(Tcl_Obj *obj, float *valp) {
    double double_val;
    if (Tcl_GetDoubleFromObj(interp, obj, &double_val) == TCL_OK) {
      *valp = double_val;
      return TCL_OK;
    }
    return TCL_ERROR;
  }
  
  // cget command implementation
  int _cget() {
    FAUSTFLOAT *optvalptr;
    if (argc != 3) return _error_obj(Tcl_ObjPrintf("usage: %s cget -option", argv[0]));
    if (_optionLookup(objv[2], &optvalptr) != TCL_OK) return TCL_ERROR;
    return _success_obj(Tcl_NewDoubleObj(*optvalptr));
  }

  // configure command implementation
  int _configure() {
    if (argc < 2 || (argc&1) != 0)
      return _error_obj(Tcl_ObjPrintf("usage: %s configure [-option value ...]", Tcl_GetString(objv[0])));
    if (argc == 2) {
      Tcl_ResetResult(interp);
      int index = 0;
      for (auto & it : interface->getShortnameMap()) {
	Tcl_AppendResult(interp,  (index++ == 0 ? "" : " "), "-", it.first.c_str(), " ", Tcl_GetString(Tcl_NewDoubleObj(*it.second)), NULL);
      }
      return TCL_OK;
    }
    for (int a = 2; a+1 < argc; a += 2) {
      if (! arg_used[a]) {
	FAUSTFLOAT *optvalptr, val;
	if (_optionLookup(objv[a], &optvalptr) != TCL_OK) return TCL_ERROR;
	if (_getFloatFromObj(objv[a+1], &val) == TCL_ERROR) return TCL_ERROR;
	*optvalptr = val;
      }
    }
    return TCL_OK;
  }

  int _command() {
    _init_for_argc();
    if (argc < 2) {
      return _error_obj(Tcl_ObjPrintf("usage: %s name method [...]", argv[0]));
    } else {
      const char *method = Tcl_GetString(objv[1]);
      if (strcmp(method, "configure") == 0) return _configure();
      if (strcmp(method, "cget") == 0) return _cget();
      if (strcmp(method, "meta") == 0) return _success_obj(meta_dict);
      if (strcmp(method, "ui") == 0) return _success_obj(ui_list);
      return _error_obj(Tcl_ObjPrintf("usage: %s name configure|cget|meta|ui [...]", Tcl_GetString(objv[0])));
    }
  }

  void _analyze() {
    MidiMeta::analyse(DSP, midi_sync, nvoices);
  }
  
  // these need to parse and search metadata too
  int _getoptionint(const char *optname, int defaultvalue) {
    int optvalue;
    for (int i = 2; i+1 < argc; i += 2)
      if (arg_used[i] == false && strcmp(optname, Tcl_GetString(objv[i])) == 0) 
	if (Tcl_GetIntFromObj(interp, objv[i+1], &optvalue) == TCL_OK) {
	  arg_used[i] = true;
	  arg_used[i+1] = true;
	  return optvalue;
	}
    return defaultvalue;
  }
  
  bool _getoptionbool(const char *optname, bool defaultvalue) {
    int optvalue;
    for (int i = 2; i+1 < argc; i += 2)
      if (arg_used[i] == false && strcmp(optname, Tcl_GetString(objv[i])) == 0)
	if (Tcl_GetBooleanFromObj(interp, objv[i+1], &optvalue) == TCL_OK) {
	  arg_used[i] = true;
	  arg_used[i+1] = true;
	  return optvalue;
	}
    return defaultvalue;
  }
  
  int _dspUpdateError(dsp *newDSP) {
    if (newDSP == NULL) {
      _error_str("Faust DSP allocation failure");
      return 1;
    } else {
      DSP = newDSP;
      return 0;
    }
  }

  // the factory command which builds instances faust dsp instruments or effects
  // _command and _delete are used at the very end of the method
  int _factory(Tcl_ObjCmdProc *_command, Tcl_CmdDeleteProc *_delete) {
    if (DSP == NULL) {
      return _error_str("Faust DSP allocation failure");
    }

    // test for insufficient arguments
    if (argc < 2 || (argc&1) != 0) {
      return _error_obj(Tcl_ObjPrintf("usage: %s name [-option value ...]", Tcl_GetString(objv[0])));
    }

    // initialize command data
    Tcl_IncrRefCount(class_name = objv[0]);
    Tcl_IncrRefCount(command_name = objv[1]);

    // build the TclTk interface
    meta_dict = Tcl_NewDictObj();
    Tcl_IncrRefCount(meta_dict);
    DSP->metadata(new TclTkMeta(interp, meta_dict) );
    ui_list = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(ui_list);
    interface = new TclTkGUI(interp, ui_list, command_name, DSP);
    DSP->buildUserInterface(interface);

    // search for midi timing options
    // and nvoices specifications in meta data.
    midi_sync = false;
    control = true;
    nvoices = 0;
    MidiMeta::analyse(DSP, midi_sync, nvoices);
    nvoices = _getoptionint("-nvoices", nvoices);
    control = _getoptionbool("-control", control);
    group = _getoptionbool("-group", 1);
    
    // create options to command
    opt_midi = _getoptionbool("-midi", false);

    cout << "Started with " << nvoices << " voices\n";

    if (nvoices > 1) {
      // make a polyphonic synth
      if (_dspUpdateError(new mydsp_poly(DSP, nvoices, control, group)))
	return TCL_ERROR;
      // disabled because I can't find effect.h except in #includes in architecture files
      // add a common effect to the output
      // if (_dspUpdateError(new dsp_sequencer(DSP, new effect())))
      //    return TCL_ERROR;
    }

    if (opt_midi && midi_sync) {
      // add midi timing support
      if (_dspUpdateError(new timed_dsp(DSP)))
	return TCL_ERROR;
    }

#ifdef FILEUI
    if (_getoptionbool("-file", true)) { 
      finterface = new FUI();
      // .config works for Linux and MacOS
      Tcl_IncrRefCount((rc_file_name = Tcl_ObjPrintf("%s/.config/faustcl/%s", getenv("HOME"), Tcl_GetString(command_name))));
    }
#endif
#ifdef PRESETUI
    if (_getoptionbool("-preset", false)) {
      pinterface = new PresetUI(interface, string(PRESETDIR) + string(Tcl_GetString(command_name)) + string((nvoices > 0) ? "_poly" : ""));
      DSP->buildUserInterface(pinterface);
    }
#endif
    
#ifdef HTTPCTRL
    if (_getoptionbool("-httpd", false)) {
      // FIX.ME - need to build const char * const * argv
      httpdinterface = new httpdUI(string(Tcl_GetString(command_name)), DSP->getNumInputs(), DSP->getNumOutputs(), argc, argv);
      DSP->buildUserInterface(httpdinterface);
      cout << "HTTPD is on" << endl;
    }
#endif
    
#ifdef OCVCTRL
    if (_getoptionbool("-ocv", 0)) {
      DSP->buildUserInterface(ocvinterface);
      cout << "OCVCTRL defined" << endl;
    }
#endif
    
#ifdef MIDICTRL
    AUDIO = new jackaudio_midi();
#else
    AUDIO = new jackaudio();
#endif

    if (AUDIO == NULL) return _error_str("Faust audio allocation failure");

    // parse command line options
    if (argc > 2 && _configure() != TCL_OK) return TCL_ERROR;

    // initialize the audio
    if ( ! AUDIO->init(Tcl_GetString(command_name), DSP)) {
      return _error_str("Unable to init audio");
    }

    // also, ignore these for the moment
#ifdef SOUNDFILE
    if (_getoptionbool("-soundfile", false)) {
      soundinterface new SoundUI("", AUDIO->getSampleRate());
      DSP->buildUserInterface(soundinterface);
    }
#endif
 
#ifdef OSCCTRL
    if (_getoptionbool("-osc", false)) {
      // FIX.ME - need const char **argv;
      oscinterface = new OSCUI(name, argc, argv);
      DSP->buildUserInterface(oscinterface);
      cout << "OSC is on" << endl;
    }
#endif

#ifdef MIDICTRL
    if (opt_midi) {
      midiinterface = new MidiUI(AUDIO);
      cout << "JACK MIDI is used" << endl;
      DSP->buildUserInterface(midiinterface);
      cout << "MIDI is on" << endl;
    }
#endif
    
    if (!AUDIO->start()) {
      cerr << "Unable to start audio" << endl;
      exit(1);
    }
    
    cout << "ins " << AUDIO->getNumInputs() << endl;
    cout << "outs " << AUDIO->getNumOutputs() << endl;

    // run user interfaces
#ifdef HTTPCTRL
    if (httpdinterface) httpdinterface->run();
#endif
    
#ifdef OCVCTRL
    if (ocvinterface) ocvinterface->run();
#endif
    
#ifdef OSCCTRL
    if (oscinterface) oscinterface->run();
#endif
    
#ifdef MIDICTRL
    if (midiinterface && ! midiinterface->run()) cerr << "MidiUI run error " << endl;
#endif
    
    // After the allocation of controllers
#ifdef FILEUI
    if (finterface) finterface->recallState(Tcl_GetString(rc_file_name));
#endif
  
    // if (interface) interface->run();

    // create Tcl command
    Tcl_CreateObjCommand(interp, Tcl_GetString(command_name), _command, (ClientData)this, _delete);

    return _success_obj(objv[1]);
  }
};

#ifdef __cplusplus
extern "C"
{
#endif

  // the command which implements instances of faust dsp instruments of effects
  static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    _client_data_t *cdata = ((_client_data_t *)clientData);
    cdata->interp = interp;
    cdata->argc = argc;
    cdata->objv = objv;
    return cdata->_command();
  }

  static void _delete(ClientData clientData) {
    delete ((_client_data_t *)clientData);
  }
  
  int jacktcl_factory(dsp *DSP, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    _client_data_t *cdata = new _client_data_t(DSP, interp, argc, objv);
    return cdata->_factory(_command, _delete);
  }

#ifdef __cplusplus
}
#endif

/******************* BEGIN jacktcl.cpp ****************/
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
