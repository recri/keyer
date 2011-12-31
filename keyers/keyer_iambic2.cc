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

#include "KeyerIambic.hh"

static KeyerIambic k;

extern "C" {

#include <jack/jack.h>
#include <jack/midiport.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>

#include "keyer_options.h"
#include "keyer_midi.h"
#include "keyer_timing.h"
#include "keyer_framework.h"

  typedef struct {
    keyer_timing_t samples_per;
    unsigned char note_on[3];
    unsigned char note_off[3];
  } keyer_data_t;
  
  static keyer_framework_t fw;
  static keyer_data_t data;

  unsigned long frames;

  // update the computed parameters
  static void iambic_update() {
    if (fw.opts.modified) {
      fw.opts.modified = 0;
      if (fw.opts.verbose > 2) fprintf(stderr, "%ld: recomputing data from options\n", frames);

      /* keyer recomputation */
      k.setTick(1000000.0 / fw.opts.sample_rate);
      k.setWord(fw.opts.word);
      k.setWpm(fw.opts.wpm);
      k.setDah(fw.opts.dah);
      k.setIes(fw.opts.ies);
      k.setIls(fw.opts.ils);
      k.setIws(fw.opts.iws);
      k.setAutoIls(fw.opts.alsp);
      k.setAutoIws(fw.opts.awsp);
      k.setSwapped(fw.opts.swap);
      k.setModeB(fw.opts.mode == 'B');

      /* midi note on/off */
      data.note_on[0] = NOTE_ON|(fw.opts.chan-1); data.note_on[1] = fw.opts.note;
      data.note_off[0] = NOTE_OFF|(fw.opts.chan-1); data.note_on[1] = fw.opts.note;

      /* pass on parameters to tone keyer */
      static keyer_options_t sent;
      char buffer[128];
      if (sent.rise != fw.opts.rise) { sprintf(buffer, "<rise%.1f>", sent.rise = fw.opts.rise); midi_sysex_write(buffer); }
      if (sent.fall != fw.opts.fall) { sprintf(buffer, "<fall%.1f>", sent.fall = fw.opts.fall); midi_sysex_write(buffer); }
      if (sent.freq != fw.opts.freq) { sprintf(buffer, "<freq%.1f>", sent.freq = fw.opts.freq); midi_sysex_write(buffer); }
      if (sent.gain != fw.opts.gain) { sprintf(buffer, "<gain%.1f>", sent.gain = fw.opts.gain); midi_sysex_write(buffer); }
    }
  }

  static void iambic_keyout(int key) {
    midi_write(0, 3, key ? data.note_on : data.note_off);
  }

  static void iambic_init() {
    k.setKeyOut(iambic_keyout);\
  }

  static void iambic_decode(int count, unsigned char *p) {
    if (count == 3) {
      switch (p[0]&0xF0) {
      case NOTE_OFF: if (p[1]&1) k.paddleDah(0); else k.paddleDit(0); break;
      case NOTE_ON:  if (p[1]&1) k.paddleDah(1); else k.paddleDit(1); break;
      }
    } else if (count > 3 && p[0] == SYSEX) {
      if (p[1] == SYSEX_VENDOR) {
	main_parse_command(&fw.opts, (char *)p+3);
      }
    }
  }

  /*
  ** jack process callback
  */
  static unsigned duration = 0;

  static int iambic_process_callback(jack_nframes_t nframes, void *arg) {
    void *midi_in = jack_port_get_buffer(fw.midi_in, nframes);
    void *midi_out = jack_port_get_buffer(fw.midi_out, nframes);
    jack_midi_event_t in_event;
    int in_event_count = jack_midi_get_event_count(midi_in), in_event_index = 0, in_event_time = 0;
    if (in_event_index < in_event_count) {
      jack_midi_event_get(&in_event, midi_in, in_event_index++);
      in_event_time += in_event.time;
    } else {
      in_event_time = nframes+1;
    }
    /* this is important, very strange if omitted */
    jack_midi_clear_buffer(midi_out);
    /* for all frames in the buffer */
    for(int i = 0; i < nframes; i++) {
      /* process all midi input events at this sample frame */
      while (in_event_time == i) {
	if (fw.opts.verbose > 5) fprintf(stderr, "%ld: process event %x [%x, %x, %x, ...]\n", frames, (unsigned)in_event.size, in_event.buffer[0], in_event.buffer[1], in_event.buffer[2]);
	iambic_decode(in_event.size, in_event.buffer);
	if (in_event_index < in_event_count) {
	  jack_midi_event_get(&in_event, midi_in, in_event_index++);
	  in_event_time += in_event.time;
	} else {
	  in_event_time = nframes+1;
	}
      }
      /* process all midi output events at this sample frame */
      while (duration == i) {
	if (midi_readable()) {
	  if (fw.opts.verbose > 4) fprintf(stderr, "%ld: midi_readable, duration %u, count %u\n", frames, midi_duration(), midi_count());
	  duration += midi_duration();
	  unsigned count = midi_count();
	  if (count != 0) {
	    unsigned char* buffer = jack_midi_event_reserve(midi_out, i, count);
	    if (buffer == NULL) {
	      fprintf(stderr, "%ld: jack won't buffer %d midi bytes!\n", frames, count);
	    } else {
	      midi_read_bytes(count, buffer);
	      if (fw.opts.verbose > 5) fprintf(stderr, "%ld: sent %x [%x, %x, %x, ...]\n", frames, count, buffer[0], buffer[1], buffer[2]);
	    }
	  }
	  midi_read_next();
	} else {
	  duration = nframes;
	}
      }
      /* clock the iambic keyer */
      k.clock(1);
    }
    frames += 1;
    if (duration >= nframes)
      duration -= nframes;
    return 0;
  }

  int main(int argc, char **argv) {
    keyer_framework_main(&fw, argc, argv, (char *)"keyer_iambic2", require_midi_in|require_midi_out, iambic_init, iambic_process_callback, NULL);
  }

}
