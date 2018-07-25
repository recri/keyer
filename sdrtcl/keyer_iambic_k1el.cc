/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2014 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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

    keyer_iambic implements an iambic keyer keyed by midi events
    and generating midi events.
*/

#include "../dspmath/iambic_k1el.h"

extern "C" {

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI	1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WPM 1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WORD 1
#define FRAMEWORK_OPTIONS_KEYER_TIMING_DIT 1
#define FRAMEWORK_OPTIONS_KEYER_TIMING_DAH 1
#define FRAMEWORK_OPTIONS_KEYER_TIMING_IES 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_SWAP 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_MODE 1

#include "framework.h"
#include "../dspmath/midi.h"

  typedef struct {
#include "framework_options_vars.h"
  } options_t;

  typedef struct {
    framework_t fw;
    int modified;
    options_t opts;
    iambic_k1el k;
    int raw_dit;
    int raw_dah;
    int key_out;
  } _t;

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;

      /* keyer recomputation */
      dp->k.setTick(1000000.0 / sdrkit_sample_rate(dp));
      dp->k.setWord(dp->opts.word);
      dp->k.setWpm(dp->opts.wpm);
      dp->k.setDit(dp->opts.dit);
      dp->k.setDah(dp->opts.dah);
      dp->k.setIes(dp->opts.ies);
      dp->k.setSwapped(dp->opts.swap != 0);
      dp->k.setMode(dp->opts.mode);
    }
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    dp->raw_dit = 0;
    dp->raw_dah = 0;
    dp->key_out = 0;
    dp->modified = 1;
    _update(dp);
    return arg;
  }

  static void _decode(_t *dp, int count, unsigned char *p) {
    if (count == 3) {
      unsigned char channel = (p[0]&0xF)+1;
      unsigned char command = p[0]&0xF0;
      unsigned char note = p[1];
      if (channel == dp->opts.chan) {
	if (note == dp->opts.note) {
	  switch (command) {
	  case MIDI_NOTE_OFF: dp->raw_dit = 0; break;
	  case MIDI_NOTE_ON:  dp->raw_dit = 1; break;
	  }
	} else if (note == dp->opts.note+1) {
	  switch (command) {
	  case MIDI_NOTE_OFF: dp->raw_dah = 0; break;
	  case MIDI_NOTE_ON:  dp->raw_dah = 1; break;
	  }
	}
      }
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
    // update our timings
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
	_decode(dp, in_event.size, in_event.buffer);
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time = in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
      }
      /* clock the iambic keyer */
      if (dp->k.clock(dp->raw_dit, dp->raw_dah, 1) != dp->key_out) {
	dp->key_out ^= 1;
	unsigned char midi_note_event[] = { (unsigned char)((dp->key_out ? MIDI_NOTE_ON : MIDI_NOTE_OFF) | (dp->opts.chan-1)),
					    (unsigned char)dp->opts.note, 0 };
	unsigned char* buffer = jack_midi_event_reserve(midi_out, i, 3);
	if (buffer == NULL) {
	  fprintf(stderr, "jack won't buffer 3 midi bytes!\n");
	} else {
	  memcpy(buffer, midi_note_event, 3);
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
    dp->modified = dp->modified || dp->opts.word != save.word || dp->opts.wpm != save.wpm || dp->opts.dah != save.dah ||
		    dp->opts.ies != save.ies || dp->opts.swap != save.swap || dp->opts.mode != save.mode;
    return TCL_OK;
  }

  static const fw_option_table_t _options[] = {
#include "framework_options.h"
    { NULL, NULL, NULL, NULL, fw_option_none, fw_flag_none, 0, NULL }
  };

  static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
    { NULL, NULL }
  };

  static const framework_t _template = {
    _options,			// option table
    _subcommands,		// subcommand table
    _init,			// initialization function
    _command,			// command function
    NULL,			// delete function
    NULL,			// sample rate function
    _process,			// process callback
    0, 0, 1, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
    (char *)"an iambic keyer component which translates MIDI input key events into an output MIDI key signal"
  };

  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
  }

  // okay, so tcl truncates the name before _Init at the first digit
  int DLLEXPORT Keyer_iambic_k_Init(Tcl_Interp *interp) {
    return framework_init(interp, "sdrtcl::keyer-iambic-k1el", "1.0.0", "sdrtcl::keyer-iambic-k1el", _factory);
  }

}
