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

    keyer_ptt implements a push-to-talk switch on a keyer signal
    it has a keyer input midi signal, a keyer output midi signal,
    and a PTT output midi signal.

    The PTT output on happens when the keyer input goes on.

    The keyer output can be delayed by a specified period so the
    PTT signal can lead the key.

    The PTT off signal can be lagged behind the keyer off signal.
    
*/

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "framework.h"
#include "../sdrkit/midi.h"
#include "../sdrkit/midi_buffer.h"

typedef struct {
#include "framework_options_vars.h"
  float ptt_delay;	       /* seconds ptt on leads keyer on */
  float ptt_hang;	       /* seconds ptt off trails keyer off */
} options_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  int ptt_delay_samples;
  int ptt_hang_samples;
  int ptt_on;
  int key_on;
  int ptt_hang_count;
  midi_buffer_t midi;
} _t;


// update the computed parameters
static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;
    /* ptt recomputation */
    int sample_rate = sdrkit_sample_rate(dp);
    dp->ptt_delay_samples = dp->opts.ptt_delay * sample_rate;
    dp->ptt_hang_samples = dp->opts.ptt_hang * sample_rate;
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  void *p = midi_buffer_init(&dp->midi); if (p != &dp->midi) return p;
  dp->ptt_on = 0;
  dp->key_on = 0;
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
  void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  jack_midi_event_t event;
  // initialize input event queue
  framework_midi_event_init(&dp->fw, &dp->midi, nframes);
  // recompute timings if necessary
  _update(dp);
  /* this is important, very strange if omitted */
  jack_midi_clear_buffer(midi_out);
  /* for all frames in the buffer */
  for (int i = 0; i < nframes; i++) {
    /* read all events for this frame */
    int port;
    while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
      if (port < dp->fw.n_midi_inputs) {
	/* it is a midi_input event */
	if (event.size == 3) {
	  const unsigned char channel = (event.buffer[0]&0xF)+1;
	  const unsigned char command = event.buffer[0]&0xF0;
	  const unsigned char note = event.buffer[1];
	  if (channel == dp->opts.chan && note == dp->opts.note) {
	    if (command == MIDI_NOTE_ON) {
	      if ( ! dp->ptt_on) {
		dp->ptt_on = 1;
		_send(dp, midi_out, i, command, dp->opts.note+1);
	      }
	      dp->key_on = 1;
	      if (i+dp->ptt_delay_samples < nframes) {
		_send(dp, midi_out, i+dp->ptt_delay_samples, command, dp->opts.note);
	      } else {
		midi_buffer_write_delay(&dp->midi, i+dp->ptt_delay_samples-nframes);
		midi_buffer_write_note_on(&dp->midi, 0, channel, note, 0);
	      }
	    } else if (command == MIDI_NOTE_OFF) {
	      if (i+dp->ptt_delay_samples < nframes) {
		dp->key_on = 0;
		dp->ptt_hang_count = dp->ptt_hang_samples+dp->ptt_delay_samples;
		_send(dp, midi_out, i+dp->ptt_delay_samples, command, dp->opts.note);
	      } else {
		midi_buffer_write_delay(&dp->midi, i+dp->ptt_delay_samples-nframes);
		midi_buffer_write_note_off(&dp->midi, 0, channel, note, 0);
	      }
	    }
	  }
	}
      } else {
	/* it is a midi buffer event */
	if (event.size != 0) {
	  const unsigned char command = event.buffer[0]&0xF0;
	  if (command == MIDI_NOTE_ON) {
	    dp->key_on = 1;
	  } else if (command == MIDI_NOTE_OFF) {
	    dp->key_on = 0;
	    dp->ptt_hang_count = dp->ptt_hang_samples;
	  }
	  _send(dp, midi_out, i, command, dp->opts.note);
	}
      }
    }
    /* clock the ptt hang time counter */
    if (dp->key_on == 0 && dp->ptt_on != 0 && --dp->ptt_hang_count <= 0) {
      dp->ptt_on = 0;
      _send(dp, midi_out, i, MIDI_NOTE_OFF, dp->opts.note+1);
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
  dp->modified = (dp->opts.ptt_delay != save.ptt_delay || dp->opts.ptt_hang != save.ptt_hang);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  // ptt options
  { "-delay",   "delay",   "Delay",   "0.0",      fw_option_float, 0, offsetof(_t, opts.ptt_delay), "delay of keyer on behind ptt on in seconds" },
  { "-hang",    "hang",    "Hang",    "1.0",      fw_option_float, 0, offsetof(_t, opts.ptt_hang),  "hang time of ptt off behind keyer off in seconds" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  0, 0, 1, 1, 1,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for splitting a MIDI keyer signal into a, possibly delayed, MIDI keyer signal and a separate MIDI push-to-talk signal"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_ptt_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::ptt", "1.0.0", "keyer::ptt", _factory);
}

