/*
  Copyright (C) 2011 Roger E Critchlow Jr, rec@elf.org

  keyer_decode reads midi note on and note off, infers a dit clock,
  and produces a string of dits, dahs, and spaces.

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

#include <stdio.h>

#include <jack/jack.h>
#include <jack/midiport.h>

#include "keyer_options.h"
#include "keyer_midi.h"
#include "keyer_framework.h"

static keyer_framework_t fw;

unsigned frame;

/*
** The basic problem is to infer the dit clock rate from observations of dits, dahs, inter-element spaces,
** inter-letter spaces, and maybe inter-word spaces.
**
** Assume that each element observed is either a dit or a dah and record its contribution to the estimated
** dot clock as if it were both T and 3*T in length.
**
** Similarly, take each space observed as potentially T, 3*T, and 7*T in length.
*/
static void midi_decode(unsigned count, unsigned char *p) {
  /* decode note/channel based events */
  static unsigned estimate;
  static unsigned last_frame;
  if (fw.opts.verbose > 4)
    fprintf(stderr, "%d: midi_decode(%x, [%x, %x, %x, ...]\n", frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == fw.opts.chan && note == fw.opts.note) {
      unsigned observation = frame - last_frame;
      int mark;
      last_frame = frame;
      switch (p[0]&0xF0) {
      case NOTE_OFF: /* the end of a dit or a dah */
	{
	  mark = 1;
	  unsigned o1 = observation, o2 = observation / 3;
	  unsigned d1 = o1 - estimate, d2 = o2 - estimate;
	  if (d1 == 0 || d2 == 0) {
	    /* if one of the observations is spot on, the estimate is unchanged */
	  } else {
	    float w1 = 1.0 / (d1*d1), w2 = 1.0 / (d2*d2);
	    float wt = w1 + w2;
	    estimate = (unsigned)(estimate + o1 * w1 / wt + o2 * w2 / wt) / 2;
	  }
	  break;
	}
      case NOTE_ON: /* the end of an inter-element, inter-letter, or inter-word space */
	{
	  mark = 0;
	  unsigned o1 = observation, o2 = observation / 3, o3 = observation / 7;
	  unsigned d1 = o1 - estimate, d2 = o2 - estimate, d3 = o3 - estimate;
	  if (d1 == 0 || d2 == 0 || d3 == 0) {
	    /* if one of the observations is spot on, the estimate is unchanged */
	  } else {
	    float w1 = 1.0 / (d1*d1), w2 = 1.0 / (d2*d2), w3 = 1.0 / (d3*d3);
	    float wt = w1 + w2 + w3;
	    estimate = (unsigned)(estimate + o1 * w1 / wt + o2 * w2 / wt + o3 * w3 / wt) / 2;
	  }
	  break;
	}
      }
      fprintf(stderr, "T=%d, M=%d, 10*O/T=%d\n", estimate, mark, 18*observation/estimate);
    } else if (fw.opts.verbose > 3)
      fprintf(stderr, "discarded midi chan=0x%x note=0x%x != mychan=0x%x mynote=0x%x\n", channel, note, fw.opts.chan, fw.opts.note);
  } else if (count > 3 && p[0] == SYSEX) {
    if (p[1] == SYSEX_VENDOR) {
      main_parse_command(&fw.opts, p+3);
      if (fw.opts.verbose > 3)
	fprintf(stderr, "sysex: %*s\n", count, p+2);
    }
  }
}

/*
** Jack
*/

static int decode_process_callback(jack_nframes_t nframes, void *arg) {
  void* midi_in = jack_port_get_buffer(fw.midi_in, nframes);
  jack_midi_event_t in_event;
  jack_nframes_t event_count = jack_midi_get_event_count(midi_in), event_index = 0, event_time = 0;
  /* initialize */
  if (event_index < event_count) {
    jack_midi_event_get(&in_event, midi_in, event_index++);
    event_time += in_event.time;
  } else {
    event_time = nframes+1;
  }
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    while (event_time == i) {
      midi_decode(in_event.size, in_event.buffer);
      if (event_index < event_count) {
	jack_midi_event_get(&in_event, midi_in, event_index++);
	event_time += in_event.time;
      } else {
	event_time = nframes+1;
      }
    }
    /* increment the frame counter */
    frame += 1;
  }
  return 0;
}

int main(int narg, char **args) {
  fw.default_client_name = "keyer_decode";
  fw.ports_required = require_midi_in;
  fw.process_callback = decode_process_callback;
  fw.init = NULL;
  fw.receive_input_char = NULL;
  keyer_framework_main(&fw, narg, args);
}

