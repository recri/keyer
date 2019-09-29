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
#include "../dspmath/midi.h"
/*
** Create a midi event delay.
*/

typedef struct {
#include "framework_options_vars.h"
  float delay;		       /* milliseconds delay */
  float hang;		       /* milliseconds hang after note off */
} options_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  int delay_samples;		// delay length in samples
  int hang_samples;		// hang time in samples
  int key_on;			// key signal high
  int ptt_on;			// ptt signal high
  int hang_count;		// count down hang time when ptt_on && ! key_on
  ring_buffer_t rb;
  unsigned char buff[8192];
} _t;

// update the computed parameters
static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = dp->fw.busy = 0;
    int sample_rate = sdrkit_sample_rate(dp);
    dp->delay_samples = dp->opts.delay * sample_rate / 1000.0;
    dp->hang_samples = dp->opts.hang * sample_rate / 1000.0;
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  void *e = ring_buffer_init(&dp->rb, sizeof(dp->buff), dp->buff); if (e != &dp->rb) return e;
  dp->ptt_on = 0;
  dp->modified = dp->fw.busy = 1;
  _update(dp);
  return arg;
}

static int _writeable(_t *data) {
  return ring_buffer_items_available_to_write(&data->rb) >= 4+sizeof(jack_nframes_t);
}

static void _write(_t *data, jack_nframes_t frame, unsigned char *buff) {
  ring_buffer_put(&data->rb, sizeof(frame), (unsigned char *)&frame);
  ring_buffer_put(&data->rb, 4, buff);
}

static int _readable(_t *data) {
  return ring_buffer_items_available_to_read(&data->rb) >= 4+sizeof(jack_nframes_t);
}
  
static jack_nframes_t _peek_time(_t *dp) {
  jack_nframes_t *framep;
  framep = (jack_nframes_t *)ring_buffer_peek_pointer(&dp->rb, sizeof(*framep));
  return framep == NULL ? 0 : *framep;
}

static int _read(_t *data, jack_nframes_t *framep, unsigned char *bytes) {
  int n = 0;
  n += ring_buffer_get(&data->rb, sizeof(*framep), (unsigned char *)framep);
  n += ring_buffer_get(&data->rb, 4, bytes);
  return n;
}

static void _sendmidi(_t *dp, void *midi_out, jack_nframes_t t, unsigned char midi[3]) {
  unsigned char* buffer = jack_midi_event_reserve(midi_out, t, 3);
  if (buffer == NULL) {
    fprintf(stderr, "jack won't buffer 3 midi bytes!\n");
  } else {
    memcpy(buffer, midi, 3);
  }
}

static void _send(_t *dp, void *midi_out, jack_nframes_t t, unsigned char cmd, unsigned char note) {
  unsigned char midi[] = { cmd | (dp->opts.chan-1), note, 0 };
  _sendmidi(dp, midi_out, t, midi);
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  framework_midi_event_init(&dp->fw, NULL, nframes);
  _update(dp);
  jack_midi_clear_buffer(midi_out);
  /* for all frames in the buffer */
  jack_nframes_t frame = sdrkit_last_frame_time(arg);
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    /* discard anything with more than 3 bytes of data */
    jack_midi_event_t event;
    int port;
    while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
      if (event.size == 3 && _writeable(dp)) {
	const unsigned char command = (event.buffer[0]&0xF0);
	const unsigned char channel = (event.buffer[0]&0xF)+1;
	const unsigned char note = event.buffer[1];
	if ((command == MIDI_NOTE_ON || command == MIDI_NOTE_OFF) &&
	    channel == dp->opts.chan && note == dp->opts.note) {
	  // delay the note
	  _write(dp, frame+i+dp->delay_samples, event.buffer);
	  // start the ptt if necessary
	  // maintain the key state
	  if (command == MIDI_NOTE_ON) {
	    dp->key_on = 1;
	    if ( ! dp->ptt_on) {
	      dp->ptt_on = 1;
	      _send(dp, midi_out, i, MIDI_NOTE_ON, dp->opts.note+1);
	    }
	  }
	}
      }
    }
    // read the delayed note(s) for this frame
    // only midi on my channel
    while (_readable(dp) && _peek_time(dp) == frame+i) {
      jack_nframes_t mframe;
      unsigned char midi[4];
      _read(dp, &mframe, midi);
      const unsigned char command = (midi[0]&0xF0);
      if (command == MIDI_NOTE_ON) {
	dp->key_on = 1;
      } else if (command == MIDI_NOTE_OFF) {
	dp->key_on = 0;		// key state off
	dp->hang_count = dp->hang_samples;
      }
      _sendmidi(dp, midi_out, i, midi);
    }
    /* clock the ptt hang time counter */
    if ( ! dp->key_on && dp->ptt_on && --dp->hang_count <= 0) {
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
  dp->modified = dp->fw.busy = (dp->modified || dp->opts.delay != save.delay || dp->opts.hang != save.hang);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-delay", "delay", "Delay", "0.0", fw_option_float, 0, offsetof(_t, opts.delay), "delay of midi events in milliseconds" },
  { "-hang",  "hang",  "Hang",  "0.0", fw_option_float, 0, offsetof(_t, opts.hang),  "hang time to ptt off behind keyer off in milliseconds" },
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
  0, 0, 1, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which delays MIDI events in Jack"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_ptt_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::keyer-ptt", "1.0.0", "sdrtcl::keyer-ptt", _factory);
}

