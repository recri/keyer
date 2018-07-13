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
embed the dttsp_keyer, more work to do.    
*/


#include "../dspmath/iambic_dttsp.h"

extern "C" {

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "framework.h"
#include "../dspmath/midi.h"

  typedef struct {
#include "framework_options_vars.h"
    int swap;
    iambic_dttsp_options_t key_opts;
  } options_t;

  typedef struct {
    framework_t fw;
    iambic_dttsp_t key;
    int modified;
    options_t opts;
    int raw_dit, raw_dah, key_out;
    float millis_per_frame;
  } _t;

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;
      iambic_dttsp_configure(&dp->key, &dp->opts.key_opts);
    }
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    void *p = iambic_dttsp_init(&dp->key, &dp->opts.key_opts); if (p != &dp->key) return p;
    dp->millis_per_frame = 1000.0f / jack_get_sample_rate(dp->fw.client);
    dp->modified = 1;
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
    // fetch options if necessary
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
      int look_for_more_events = 0;
      /* process all midi input events at this sample frame */
      while (in_event_time == i) {
	_decode(dp, in_event.size, in_event.buffer); // this might trigger a keyout
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time = in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
	look_for_more_events = 1;
      }
      /* clock the iambic keyer */
      if (iambic_dttsp_process(&dp->key, dp->raw_dit, dp->raw_dah, dp->millis_per_frame) != dp->key_out) {
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
    _t *data = (_t *)clientData;
    options_t save = data->opts;
    if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
      data->opts = save;
      return TCL_ERROR;
    }
    data->modified = data->modified || data->opts.key_opts.wpm != save.key_opts.wpm ||
      data->opts.key_opts.mode != save.key_opts.mode ||
      data->opts.key_opts.want_dit_mem != save.key_opts.want_dit_mem ||
      data->opts.key_opts.want_dah_mem != save.key_opts.want_dah_mem ||
      data->opts.key_opts.need_midelemodeB != save.key_opts.need_midelemodeB ||
      data->opts.key_opts.autocharspacing != save.key_opts.autocharspacing ||
      data->opts.key_opts.autowordspacing != save.key_opts.autowordspacing ||
      data->opts.key_opts.weight != save.key_opts.weight;
    return TCL_OK;
  }

  static const fw_option_table_t _options[] = {
#include "framework_options.h"
    { "-wpm",  "wpm",     "Words",   "18.0", fw_option_float,   fw_flag_none, offsetof(_t, opts.key_opts.wpm), "words per minute" },
    { "-swap", "swap",	  "Bool",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.swap), "swap the dit and dah paddles" },
    { "-mode", "mode",    "Mode",    "A",    fw_option_char,    fw_flag_none, offsetof(_t, opts.key_opts.mode), "iambic mode A or B" },
    { "-mdit", "mdit",    "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.want_dit_mem), "keep a dit memory" },
    { "-mdah", "mdah",	  "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.want_dah_mem), "keep a dah memory" },
    { "-mide", "mide",    "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.need_midelemodeB), "remember key state at mid-element" },
    { "-alsp", "alsp",	  "Bool",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.autocharspacing), "auto letter spacing" },
    { "-awsp", "awsp",	  "Bool",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.autowordspacing), "auto word spacing" },
    { "-weight","weight", "Weight",  "50",   fw_option_int,     fw_flag_none, offsetof(_t, opts.key_opts.weight), "adjust relative weight of dit and dah" },
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
    (char *)"an iambic keyer component based on the dttsp iambic keyer"
  };

  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
  }

  int DLLEXPORT Keyer_iambic_dttsp_Init(Tcl_Interp *interp) {
    return framework_init(interp, "sdrtcl::keyer-iambic-dttsp", "1.0.0", "sdrtcl::keyer-iambic-dttsp", _factory);
  }

}
