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

    keyer_iambic implements an iambic keyer keyed by midi events
    and generating midi events.

*/

#include "../sdrkit/Iambic.hh"

extern "C" {

#define KEYER_OPTIONS_TONE	1
#define KEYER_OPTIONS_TIMING	1
#define KEYER_OPTIONS_KEYER	1

#include "framework.h"
#include "../sdrkit/midi.h"
#include "../sdrkit/midi_buffer.h"

  typedef struct {
#include "keyer_options_var.h"
  } options_t;

  typedef struct {
    framework_t fw;
    Iambic k;
    unsigned long frames;
    int modified;
    options_t opts;
    options_t sent;
    midi_buffer_t midi;
  } _t;

  static char *_preface(_t *dp, const char *file, int line) {
    static char buff[256];
    sprintf(buff, "%s:%s:%d@%ld", Tcl_GetString(dp->fw.client_name), file, line, dp->frames);
    return buff;
  }
  
#define PREFACE	_preface(dp, __FILE__, __LINE__)

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;
      // if (dp->opts.verbose > 2) fprintf(stderr, "%s _update\n", PREFACE);

      /* keyer recomputation */
      dp->k.setVerbose(dp->opts.verbose);
      dp->k.setTick(1000000.0 / sdrkit_sample_rate(dp));
      dp->k.setWord(dp->opts.word);
      dp->k.setWpm(dp->opts.wpm);
      dp->k.setDah(dp->opts.dah);
      dp->k.setIes(dp->opts.ies);
      dp->k.setIls(dp->opts.ils);
      dp->k.setIws(dp->opts.iws);
      dp->k.setAutoIls(dp->opts.alsp != 0);
      dp->k.setAutoIws(dp->opts.awsp != 0);
      dp->k.setSwapped(dp->opts.swap != 0);
      dp->k.setMode(dp->opts.mode);

      /* pass on parameters to tone keyer */
      char buffer[128];
      if (dp->sent.rise != dp->opts.rise) { sprintf(buffer, "<rise%.1f>", dp->sent.rise = dp->opts.rise); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.fall != dp->opts.fall) { sprintf(buffer, "<fall%.1f>", dp->sent.fall = dp->opts.fall); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.freq != dp->opts.freq) { sprintf(buffer, "<freq%.1f>", dp->sent.freq = dp->opts.freq); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.gain != dp->opts.gain) { sprintf(buffer, "<gain%.1f>", dp->sent.gain = dp->opts.gain); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      /* or to decoder */
      if (dp->sent.word != dp->opts.word) { sprintf(buffer, "<word%.1f>", dp->sent.word = dp->opts.word); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.wpm != dp->opts.wpm) { sprintf(buffer, "<wpm%.1f>", dp->sent.wpm = dp->opts.wpm); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
    }
  }

  static void _keyout(int key, void *arg) {
    _t *dp = (_t *)arg;
    // if (dp->opts.verbose) fprintf(stderr, "%s _keyout(%d)\n", PREFACE, key);
    if (key)
      midi_buffer_write_note_on(&dp->midi, 0, dp->opts.chan, dp->opts.note, 0);
    else
      midi_buffer_write_note_off(&dp->midi, 0, dp->opts.chan, dp->opts.note, 0);
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    dp->k.setKeyOut(_keyout, arg);
    void *p = midi_buffer_init(&dp->midi); if (p != &dp->midi) return p;
    dp->modified = 1;
    _update(dp);
    return arg;
  }

  static void _decode(_t *dp, int count, unsigned char *p) {
    // if (dp->opts.verbose) fprintf(stderr, "%s _decode %d bytes\n", PREFACE, count);
    if (count == 3) {
      unsigned char channel = (p[0]&0xF)+1;
      unsigned char command = p[0]&0xF0;
      unsigned char note = p[1];
      if (channel != dp->opts.chan) {
	// if (dp->opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mychan=0x%x\n", PREFACE, channel, note, dp->opts.chan, dp->opts.note);
      } else if (note == dp->opts.note) {
	// if (dp->opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
	switch (command) {
	case MIDI_NOTE_OFF: dp->k.paddleDit(false); break;
	case MIDI_NOTE_ON:  dp->k.paddleDit(true); break;
	}
      } else if (note == dp->opts.note+1) {
	// if (dp->opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
	switch (command) {
	case MIDI_NOTE_OFF: dp->k.paddleDah(false); break;
	case MIDI_NOTE_ON:  dp->k.paddleDah(true); break;
	}
      } else {
	// if (dp->opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mynote=0x%x\n", PREFACE, channel, note, dp->opts.chan, dp->opts.note);
      }
    } else if (count > 3 && p[0] == MIDI_SYSEX && p[1] == MIDI_SYSEX_VENDOR) {
      // if (dp->opts.verbose) fprintf(stderr, "%s _decode([%x, %x, %x, ...])\n", PREFACE, p[0], p[1], p[2]);
      // FIX.ME - options_parse_command(&dp->opts, (char *)p+3);
    }
  }

  /*
  ** jack process callback
  */

  static int _process(jack_nframes_t nframes, void *arg) {
    _t *dp = (_t *)arg;
    void *midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
    void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
    void* buffer_in = midi_buffer_get_buffer(&dp->midi, nframes, sdrkit_last_frame_time(dp));
    int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
    int buffer_event_count = midi_buffer_get_event_count(buffer_in), buffer_event_index = 0, buffer_event_time = 0;
    jack_midi_event_t in_event, buffer_event;
    // find out what input events we need to process
    if (in_event_index < in_event_count) {
      jack_midi_event_get(&in_event, midi_in, in_event_index++);
      in_event_time = in_event.time;
    } else {
      in_event_time = nframes+1;
    }
    // find out what buffered events we need to process
    // NB - this won't include events queued during this process callback
    if (buffer_event_index < buffer_event_count) {
      // fprintf(stderr, "iambic received %d events\n", buffer_event_count);
      midi_buffer_event_get(&buffer_event, buffer_in, buffer_event_index++);
      buffer_event_time = buffer_event.time;
    } else {
      buffer_event_time = nframes+1;
    }
    /* this is important, very strange if omitted */
    jack_midi_clear_buffer(midi_out);
    /* for all frames in the buffer */
    for(int i = 0; i < nframes; i++) {
      int look_for_more_events = 0;
      /* process all midi input events at this sample frame */
      while (in_event_time == i) {
	_decode(dp, in_event.size, in_event.buffer);
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time = in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
	look_for_more_events = 1;
      }
      /* process all midi output events at this sample frame */
      /* it's possible that input events generated more for us to do */
      while (buffer_event_time == i) {
	if (buffer_event.size != 0) {
	  unsigned char* buffer = jack_midi_event_reserve(midi_out, i, buffer_event.size);
	  if (buffer == NULL) {
	    fprintf(stderr, "%ld: jack won't buffer %ld midi bytes!\n", dp->frames, buffer_event.size);
	  } else {
	    memcpy(buffer, buffer_event.buffer, buffer_event.size);
	  }
	}
	if (buffer_event_index < buffer_event_count) {
	  midi_buffer_event_get(&buffer_event, buffer_in, buffer_event_index++);
	  buffer_event_time = buffer_event.time;
	} else {
	  buffer_event_time = nframes+1;
	}
      }
      /* clock the iambic keyer */
      dp->k.clock(1);
      /* clock the frame counter */
      dp->frames += 1;
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
  data->modified = (data->opts.word != save.word ||
		    data->opts.wpm != save.wpm ||
		    data->opts.dah != save.dah ||
		    data->opts.ies != save.ies ||
		    data->opts.ils != save.ils ||
		    data->opts.iws != save.iws ||
		    data->opts.freq != save.freq ||
		    data->opts.gain != save.gain ||
		    data->opts.rise != save.rise ||
		    data->opts.fall != save.fall ||
		    data->opts.swap != save.swap ||
		    data->opts.alsp != save.alsp ||
		    data->opts.awsp != save.awsp ||
		    data->opts.mode != save.mode);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "keyer_options_def.h"
  { NULL, NULL, NULL, NULL, fw_option_none, 0, NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
  { NULL, NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  0, 0, 1, 1			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_iambic_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::iambic", "1.0.0", "keyer::iambic", _factory);
}

}
