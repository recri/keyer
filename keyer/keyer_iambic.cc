/** 
    Copyright (c) 2011 by Roger E Critchlow Jr

    keyer_iambic implements an iambic keyer keyed by midi events
    and generating midi events.

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
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

#include "Iambic.hh"

extern "C" {

#define OPTIONS_TIMING	1
#define OPTIONS_KEYER	1

#include "framework.h"
#include "options.h"
#include "midi.h"
#include "midi_buffer.h"
#include "timing.h"

  typedef struct {
    framework_t fw;
    timing_t samples_per;
    unsigned char note_on[3];
    unsigned char note_off[3];
    Iambic k;
    unsigned duration;
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

      /* midi note on/off */
      dp->note_on[0] = NOTE_ON|(dp->fw.opts.chan-1); dp->note_on[1] = dp->fw.opts.note;
      dp->note_off[0] = NOTE_OFF|(dp->fw.opts.chan-1); dp->note_on[1] = dp->fw.opts.note;

      /* pass on parameters to tone keyer */
      char buffer[128];
      if (dp->sent.rise != dp->fw.opts.rise) { sprintf(buffer, "<rise%.1f>", dp->sent.rise = dp->fw.opts.rise); midi_sysex_write(&dp->midi, buffer); }
      if (dp->sent.fall != dp->fw.opts.fall) { sprintf(buffer, "<fall%.1f>", dp->sent.fall = dp->fw.opts.fall); midi_sysex_write(&dp->midi, buffer); }
      if (dp->sent.freq != dp->fw.opts.freq) { sprintf(buffer, "<freq%.1f>", dp->sent.freq = dp->fw.opts.freq); midi_sysex_write(&dp->midi, buffer); }
      if (dp->sent.gain != dp->fw.opts.gain) { sprintf(buffer, "<gain%.1f>", dp->sent.gain = dp->fw.opts.gain); midi_sysex_write(&dp->midi, buffer); }
    }
  }

  static void _keyout(int key, void *arg) {
    _t *dp = (_t *)arg;
    // if (dp->fw.opts.verbose) fprintf(stderr, "%s _keyout(%d)\n", PREFACE, key);
    midi_write(&dp->midi, 0, 3, key ? dp->note_on : dp->note_off);
  }

  static void _init(void *arg) {
    _t *dp = (_t *)arg;
    dp->k.setKeyOut(_keyout, arg);
    dp->duration = 0;
    midi_init(&dp->midi);
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
	case NOTE_OFF: dp->k.paddleDit(false); break;
	case NOTE_ON:dp->k.paddleDit(true); break;
	}
      } else if (note == dp->fw.opts.note+1) {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
	switch (command) {
	case NOTE_OFF: dp->k.paddleDah(false); break;
	case NOTE_ON:dp->k.paddleDah(true); break;
	}
      } else {
	// if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mynote=0x%x\n", PREFACE, channel, note, dp->fw.opts.chan, dp->fw.opts.note);
      }
    } else if (count > 3 && p[0] == SYSEX && p[1] == SYSEX_VENDOR) {
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
    jack_midi_event_t in_event;
    int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
    if (in_event_index < in_event_count) {
      jack_midi_event_get(&in_event, midi_in, in_event_index++);
      in_event_time = in_event.time;
    } else {
      in_event_time = nframes+1;
    }
    /* this is important, very strange if omitted */
    jack_midi_clear_buffer(midi_out);
    /* for all frames in the buffer */
    for(int i = 0; i < nframes; i++) {
      /* process all midi input events at this sample frame */
      while (in_event_time == i) {
	// if (dp->fw.opts.verbose > 5) fprintf(stderr, "%s process event %x [%x, %x, %x, ...]\n", PREFACE, (unsigned)in_event.size, in_event.buffer[0], in_event.buffer[1], in_event.buffer[2]);
	_decode(dp, in_event.size, in_event.buffer);
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time = in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
      }
      /* process all midi output events at this sample frame */
      while (dp->duration == i) {
	if (midi_readable(&dp->midi)) {
	  // if (dp->fw.opts.verbose > 4) fprintf(stderr, "%s midi_readable, duration %u, count %u\n", PREFACE, midi_duration(&dp->midi), midi_count(&dp->midi));
	  dp->duration += midi_duration(&dp->midi);
	  unsigned count = midi_count(&dp->midi);
	  if (count != 0) {
	    unsigned char* buffer = jack_midi_event_reserve(midi_out, i, count);
	    if (buffer == NULL) {
	      fprintf(stderr, "%ld: jack won't buffer %d midi bytes!\n", dp->frames, count);
	    } else {
	      midi_read_bytes(&dp->midi, count, buffer);
	      // if (dp->fw.opts.verbose > 5) fprintf(stderr, "%s sent %x [%x, %x, %x, ...]\n", PREFACE, count, buffer[0], buffer[1], buffer[2]);
	    }
	  }
	  midi_read_next(&dp->midi);
	} else {
	  dp->duration = nframes;
	}
      }
      /* clock the iambic keyer */
      dp->k.clock(1);
      /* clock the frame counter */
      dp->frames += 1;
    }
    if (dp->duration >= nframes)
      dp->duration -= nframes;
    return 0;
  }

#if AS_BIN
  int main(int argc, char **argv) {
    _t data;
    framework_main((void *)&data, argc, argv, (char *)"keyer_iambic2", 0,0,1,1, _init, _process, NULL);
  }
#endif
#if AS_TCL
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
#endif

}
