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

#include "../dspkit/Iambic.hh"

extern "C" {

#define OPTIONS_TIMING	1
#define OPTIONS_KEYER	1

#include "framework.h"
#include "options.h"
#include "../dspkit/midi.h"
#include "../dspkit/midi_buffer.h"

  typedef struct {
    framework_t fw;
    Iambic k;
    unsigned long frames;
    options_t sent;
    midi_buffer_t midi;
  } _t;

  static char *preface(_t *dp, const char *file, int line) {
    static char buff[256];
    sprintf(buff, "%s:%s:%d@%ld", dp->fw.opts.client, file, line, dp->frames);
    return buff;
  }
  
#define PREFACE	preface(dp, __FILE__, __LINE__)

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->fw.opts.modified) {
      dp->fw.opts.modified = 0;
      // if (dp->fw.opts.verbose > 2) fprintf(stderr, "%s _update\n", PREFACE);

      /* keyer recomputation */
      dp->k.setVerbose(dp->fw.opts.verbose);
      dp->k.setTick(1000000.0 / dp->fw.opts.sample_rate);
      dp->k.setWord(dp->fw.opts.word);
      dp->k.setWpm(dp->fw.opts.wpm);
      dp->k.setDah(dp->fw.opts.dah);
      dp->k.setIes(dp->fw.opts.ies);
      dp->k.setIls(dp->fw.opts.ils);
      dp->k.setIws(dp->fw.opts.iws);
      dp->k.setAutoIls(dp->fw.opts.alsp != 0);
      dp->k.setAutoIws(dp->fw.opts.awsp != 0);
      dp->k.setSwapped(dp->fw.opts.swap != 0);
      dp->k.setMode(dp->fw.opts.mode);

      /* pass on parameters to tone keyer */
      char buffer[128];
      if (dp->sent.rise != dp->fw.opts.rise) { sprintf(buffer, "<rise%.1f>", dp->sent.rise = dp->fw.opts.rise); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.fall != dp->fw.opts.fall) { sprintf(buffer, "<fall%.1f>", dp->sent.fall = dp->fw.opts.fall); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.freq != dp->fw.opts.freq) { sprintf(buffer, "<freq%.1f>", dp->sent.freq = dp->fw.opts.freq); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.gain != dp->fw.opts.gain) { sprintf(buffer, "<gain%.1f>", dp->sent.gain = dp->fw.opts.gain); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      /* or to decoder */
      if (dp->sent.word != dp->fw.opts.word) { sprintf(buffer, "<word%.1f>", dp->sent.word = dp->fw.opts.word); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
      if (dp->sent.wpm != dp->fw.opts.wpm) { sprintf(buffer, "<wpm%.1f>", dp->sent.wpm = dp->fw.opts.wpm); midi_buffer_write_sysex(&dp->midi, (unsigned char *)buffer); }
    }
  }

  static void _keyout(int key, void *arg) {
    _t *dp = (_t *)arg;
    // if (dp->fw.opts.verbose) fprintf(stderr, "%s _keyout(%d)\n", PREFACE, key);
    if (key)
      midi_buffer_write_note_on(&dp->midi, 0, dp->fw.opts.chan, dp->fw.opts.note, 0);
    else
      midi_buffer_write_note_off(&dp->midi, 0, dp->fw.opts.chan, dp->fw.opts.note, 0);
  }

  static void _init(void *arg) {
    _t *dp = (_t *)arg;
    dp->k.setKeyOut(_keyout, arg);
    midi_buffer_init(&dp->midi);
  }

  static void _decode(_t *dp, int count, unsigned char *p) {
    // if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode %d bytes\n", PREFACE, count);
    if (count == 3) {
      unsigned char channel = (p[0]&0xF)+1;
      unsigned char command = p[0]&0xF0;
      unsigned char note = p[1];
      if (channel != dp->fw.opts.chan) {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mychan=0x%x\n", PREFACE, channel, note, dp->fw.opts.chan, dp->fw.opts.note);
      } else if (note == dp->fw.opts.note) {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
	switch (command) {
	case MIDI_NOTE_OFF: dp->k.paddleDit(false); break;
	case MIDI_NOTE_ON:  dp->k.paddleDit(true); break;
	}
      } else if (note == dp->fw.opts.note+1) {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
	switch (command) {
	case MIDI_NOTE_OFF: dp->k.paddleDah(false); break;
	case MIDI_NOTE_ON:  dp->k.paddleDah(true); break;
	}
      } else {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mynote=0x%x\n", PREFACE, channel, note, dp->fw.opts.chan, dp->fw.opts.note);
      }
    } else if (count > 3 && p[0] == MIDI_SYSEX && p[1] == MIDI_SYSEX_VENDOR) {
      // if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, %x, ...])\n", PREFACE, p[0], p[1], p[2]);
      options_parse_command(&dp->fw.opts, (char *)p+3);
    }
  }

  /*
  ** jack process callback
  */

  static int _process(jack_nframes_t nframes, void *arg) {
    _t *dp = (_t *)arg;
    void *midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
    void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
    void* buffer_in = midi_buffer_get_buffer(&dp->midi, nframes, jack_last_frame_time(dp->fw.client));
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
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  _update((_t *)clientData);
  return TCL_OK;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, 0,0,1,1, _command, _process, sizeof(_t), _init, NULL, (char *)"config|cget|cdoc");
}

int DLLEXPORT Keyer_iambic_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer", "1.0.0", "keyer::iambic", _factory);
}

}
