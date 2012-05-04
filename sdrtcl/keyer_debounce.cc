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
/** 

    keyer_debounce implements a simple debouncing filter on the
    incoming paddle or straight key midi signals.
    
*/

typedef unsigned char byte;

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "../dspmath/debouncer.h"

extern "C" {

#include "../dspmath/midi.h"
#include "framework.h"

#ifndef DEBOUNCE_N_NOTES
#define DEBOUNCE_N_NOTES 3
#endif

  typedef struct {
#include "framework_options_vars.h"    
    float period;	  /* period of input sampling, seconds */
    int steps;		  /* number of periods of stability desired */
  } options_t;

  typedef struct {
    framework_t fw;
    int modified;
    options_t opts;
    int period_samples;
    int period_count;
    byte current[DEBOUNCE_N_NOTES];
    byte stable[DEBOUNCE_N_NOTES];
    debouncer_t deb[DEBOUNCE_N_NOTES];
    debouncer_options_t dopts;
  } _t;


  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;
      /* ptt recomputation */
      dp->period_samples = dp->opts.period * sdrkit_sample_rate(dp);
      dp->dopts.steps = dp->opts.steps;
      for (int i = 0; i < DEBOUNCE_N_NOTES; i += 1)
	debouncer_configure(&dp->deb[i], &dp->dopts);
    }
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    dp->dopts.steps = dp->opts.steps;
    for (int i = 0; i < DEBOUNCE_N_NOTES; i += 1) {
      dp->current[i] = dp->stable[i] = 0;
      void *p = debouncer_init(&dp->deb[i], &dp->dopts); if (p != &dp->deb[i]) return p;
    }
    dp->modified = 1;
    _update(dp);
    return arg;
  }

  static void _send(_t *dp, void *midi_out, jack_nframes_t t, unsigned char cmd, unsigned char note) {
    unsigned char midi[] = { cmd | (dp->opts.chan-1), note, 0 };
    unsigned char* buffer = jack_midi_event_reserve(midi_out, t, 3);
    if (buffer == NULL) {
      fprintf(stderr, "jack won't buffer 3 midi bytes!\n");
    } else {
      memcpy(buffer, midi, 3);
    }
  }

  /*
  ** jack process callback
  */
  static int _process(jack_nframes_t nframes, void *arg) {
    _t *dp = (_t *)arg;
    void *midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
    void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
    int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
    jack_midi_event_t in_event;
    // recompute timings if necessary
    _update(dp);
    // find out what input events we need to process
    if (in_event_index < in_event_count) {
      jack_midi_event_get(&in_event, midi_in, in_event_index++);
      in_event_time = in_event.time;
    } else {
      in_event_time = nframes+1;
    }
    /* this is important, very strange if omitted */
    jack_midi_clear_buffer(midi_out);
    /* for all frames in the buffer */
    for (int i = 0; i < nframes; i++) {
      /* process all midi input events at this sample frame */
      while (in_event_time == i) {
	if (in_event.size == 3) {
	  const unsigned char channel = (in_event.buffer[0]&0xF)+1;
	  const unsigned char command = in_event.buffer[0]&0xF0;
	  const unsigned char note = in_event.buffer[1];
	  if (channel == dp->opts.chan) {
	    if (note >= dp->opts.note && note < dp->opts.note+DEBOUNCE_N_NOTES) {
	      if (command == MIDI_NOTE_ON) {
		dp->current[note-dp->opts.note] = 1;
	      } else if (command == MIDI_NOTE_OFF) {
		dp->current[note-dp->opts.note] = 0;
	      }
	    }
	  }
	}
	// look for another event
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time = in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
      }
      /* clock the period counter */
      if (--dp->period_count <= 0) {
	dp->period_count = dp->period_samples;
	for (int j = 0; j < DEBOUNCE_N_NOTES; j += 1) {
	  if (debouncer_process(&dp->deb[j], dp->current[j]) != dp->stable[j]) {
	    dp->stable[j] ^= 1;
	    _send(dp, midi_out, i, dp->stable[j] ? MIDI_NOTE_ON : MIDI_NOTE_OFF, dp->opts.note+j);
	  }
	}
      }
    }
    return 0;
  }

  static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    _t *dp = (_t *)clientData;
    options_t save = dp->opts;
    if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
      dp->opts = save;
      return TCL_ERROR;
    }
    dp->modified = (dp->opts.period != save.period || dp->opts.steps != save.steps);
    if (dp->modified && dp->opts.steps > 8*sizeof(unsigned long)) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("steps %d is too large, must be <= %d", dp->opts.steps, 8*sizeof(unsigned long)));
      dp->opts = save;
      dp->modified = 0;
      return TCL_ERROR;
    }
    return TCL_OK;
  }

  static const fw_option_table_t _options[] = {
#include "framework_options.h"
    // debounce options
    { "-period",  "period",  "Period",   "0.0002",  fw_option_float, fw_flag_none, offsetof(_t, opts.period), "key sampling period in seconds" },
    { "-steps",   "steps",   "Steps",    "6",       fw_option_int,   fw_flag_none, offsetof(_t, opts.steps),  "number of consistent samples define stability" },
    { NULL, NULL, NULL, NULL, fw_option_none, fw_flag_none, 0, NULL }
  };

  static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"    
    { NULL, NULL, NULL }
  };

  static const framework_t _template = {
    _options,		    // option table
    _subcommands,	    // subcommand table
    _init,		    // initialization function
    _command,		    // command function
    NULL,		    // delete function
    NULL,		    // sample rate function
    _process,		    // process callback
    0, 0, 1, 1, 0,	    // inputs,outputs,midi_inputs,midi_outputs
    (char *)"a component which filters MIDI inputs to provide debounced MIDI outputs"
  };

  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
  }

  int DLLEXPORT Keyer_debounce_Init(Tcl_Interp *interp) {
    return framework_init(interp, "sdrtcl::keyer-debounce", "1.0.0", "sdrtcl::keyer-debounce", _factory);
  }

}
