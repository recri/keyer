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

/*
** iambic keyer
*/

#define KEYIN(dit,dah)	(((dit)<<1)|(dah))
#define KEYIN_OFF	KEYIN(0,0)
#define KEYIN_DIT	KEYIN(1,0)
#define KEYIN_DAH	KEYIN(0,1)
#define KEYIN_DIDAH	KEYIN(1,1)
#define KEYIN_IS_DIT(k)	((k)&KEYIN_DIT)
#define KEYIN_IS_DAH(k)	((k)&KEYIN_DAH)

typedef enum {
  IAMBIC_OFF, IAMBIC_DIT, IAMBIC_DIT_SPACE, IAMBIC_DAH, IAMBIC_DAH_SPACE, IAMBIC_SYMBOL_SPACE, IAMBIC_WORD_SPACE
} iambic_state_t;

static char *iambic_keys[] = {
  "OFF", "DAH", "DIT", "DIDAH"
};

static char *iambic_states[] = {
  "OFF", "DIT", "DIT_SPACE", "DAH", "DAH_SPACE", "SYMBOL_SPACE", "WORD_SPACE"
};

typedef struct {
  char _modified;

  char _inDit;
  char _inDah;

  int _keyerDuration;
  char _keyIn;
  char _lastKeyIn;
  iambic_state_t _keyerState;

  int _halfClock;
  int _halfClockCounter;
#define KEY_IN_MEM	8
  char _prevKeyIn[KEY_IN_MEM];
  unsigned _prevKeyInPtr;
} iambic_t;

iambic_t iambic;

unsigned long frames;

// initialize the iambic keyer
static void iambic_init() {
  if (fw.opts.verbose > 2) fprintf(stderr, "%ld: iambic_init()\n", frames);
  iambic._modified = 1;
  iambic._inDit = 0;		/* the midi dit value */
  iambic._inDah = 0;		/* the midi dah value */
  iambic._keyIn = KEYIN_OFF;
  iambic._lastKeyIn = KEYIN_OFF;
  iambic._keyerState = IAMBIC_OFF;
}

// update the computed parameters
static void iambic_update() {
  if (fw.opts.modified) {
    fw.opts.modified = 0;

    if (fw.opts.verbose > 2) fprintf(stderr, "%ld: recomputing data from options\n", frames);

    /* timer recomputation */
    keyer_timing_update(&fw.opts, &data.samples_per);
    if (fw.opts.verbose) keyer_timing_report(stderr, &fw.opts, &data.samples_per);

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

    /* trigger iambic updates */
    iambic._modified = 1;
  }
  if (iambic._modified) {
    iambic._modified = 0;
    iambic._halfClock = data.samples_per.dit / 2;
  }
}

// transition to the specified state
// with the specified duration
static char iambic_transition_to(iambic_state_t newState, unsigned newDuration) {
  if (fw.opts.verbose > 5) fprintf(stderr, "%ld: to %s for %d\n", frames, iambic_states[newState], newDuration);
  iambic._keyerState = newState;
  iambic._keyerDuration += newDuration;
  return 1;
}

// transition to the specified state
// with the specified state duration
// and send a key event with specified duration
static char iambic_key_and_transition_to(iambic_state_t newState, unsigned newDuration, char keyOut) {
  if (fw.opts.verbose > 5) fprintf(stderr, "%ld: key %d %x\n", frames, newDuration, keyOut);
  midi_write(newDuration, 3, keyOut ? data.note_on : data.note_off);
  return iambic_transition_to(newState, newDuration);
}

// start a dit if _dit is pressed
static char iambic_start_dit() {
  return KEYIN_IS_DIT(iambic._keyIn) ? iambic_key_and_transition_to(IAMBIC_DIT, data.samples_per.dit, 1) : 0;
}

// start a dah if _dah is pressed or
//   if _mode == IAMBIC_MODE_B and
//   squeeze was released after the last element started and
//   dah was next
static char iambic_start_dah() {
  return KEYIN_IS_DAH(iambic._keyIn) ? iambic_key_and_transition_to(IAMBIC_DAH, data.samples_per.dah, 1) : 0;
}

// continue an interelement space to an intersymbol space
// or an intersymbol space to an interword space
static char iambic_continue_space(iambic_state_t newState, unsigned newDuration) {
  if (fw.opts.verbose > 5) fprintf(stderr, "%ld: continue space %d\n", frames, newDuration);
  midi_write(newDuration, 0, "");
  return iambic_transition_to(newState, newDuration);
}

static char iambic_symbol_space() {
  return fw.opts.alsp ? iambic_continue_space(IAMBIC_SYMBOL_SPACE, data.samples_per.ils-data.samples_per.ies) : 0;
}

static char iambic_word_space() {
  return fw.opts.awsp ? iambic_continue_space(IAMBIC_WORD_SPACE, data.samples_per.iws-data.samples_per.ils) : 0;
}

// return to keyer idle state
static char iambic_finish() {
  return iambic_transition_to(IAMBIC_OFF, 0L);
}

// at the beginning of the next symbol
// we may be currently at dit+dah, but
// we want to start with which ever
// paddle was pressed first
static char iambic_start_symbol() {
  if (iambic._keyIn != KEYIN_DIDAH || iambic._lastKeyIn != KEYIN_DAH)
    return iambic_start_dit() || iambic_start_dah() ? 1 : 0;
  else
    return iambic_start_dah() || iambic_start_dit() ? 1 : 0;
}

// start an interelement space
static char iambic_start_space(iambic_state_t newState) {
  return iambic_key_and_transition_to(newState, data.samples_per.ies, 0);
}

// process keyer state
// and generate transitions
static void iambic_transition(unsigned samples) {
  // construct input key state
  char keyIn = fw.opts.swap ? KEYIN(iambic._inDah, iambic._inDit) : KEYIN(iambic._inDit, iambic._inDah);
  if (iambic._keyIn != keyIn) {
    if (fw.opts.verbose > 5) fprintf(stderr, "%ld: keyIn %x\n", frames, keyIn);
    iambic._lastKeyIn = iambic._keyIn;
  }
  iambic._keyIn = keyIn;

  // start a symbol if either paddle is pressed
  if (iambic._keyerState == IAMBIC_OFF) {
    iambic_start_symbol();
    iambic._halfClockCounter = iambic._halfClock;
    iambic._prevKeyIn[iambic._prevKeyInPtr++ & (KEY_IN_MEM-1)] = keyIn;
    return;
  }

  // reduce the half clock by the time elapsed
  iambic._halfClockCounter -= samples;

  // if the half clock has elapsed, reset it
  if (iambic._halfClockCounter < 0) {
    iambic._halfClockCounter = iambic._halfClock;
    iambic._prevKeyIn[iambic._prevKeyInPtr++ & (KEY_IN_MEM-1)] = keyIn;
  }

  // reduce the duration by the time elapsed
  iambic._keyerDuration -= samples;

  // if the duration has not elapsed, return
  if (iambic._keyerDuration > 0) {
    return;
  }
  
  // compute updated parameters 
  iambic_update();

  if (fw.opts.verbose > 4) fprintf(stderr, "%ld: dur %d key %s state %s\n", frames, iambic._keyerDuration, iambic_keys[iambic._keyIn], iambic_states[iambic._keyerState]);

  // determine the next element by the current paddle state
  switch (iambic._keyerState) {
  case IAMBIC_DIT: // finish the dit with an interelement space
    iambic_start_space(IAMBIC_DIT_SPACE);
    return;
  case IAMBIC_DAH: // finish the dah with an interelement space
    iambic_start_space(IAMBIC_DAH_SPACE);
    return;
  case IAMBIC_DIT_SPACE: // start the next element or finish the symbol
    iambic_start_dah() || iambic_start_dit() || iambic_symbol_space() || iambic_finish();
    return;
  case IAMBIC_DAH_SPACE: // start the next element or finish the symbol	
    iambic_start_dit() || iambic_start_dah() || iambic_symbol_space() || iambic_finish();
    return;
  case IAMBIC_SYMBOL_SPACE: // start a new symbol or finish the word
    iambic_start_symbol() || iambic_word_space() || iambic_finish();
    return;
  case IAMBIC_WORD_SPACE:  // start a new symbol or go to off
    iambic_start_symbol() || iambic_finish();
    return;
  }
}

static void iambic_dit_key(int on) {
  iambic._inDit = on;
}

static void iambic_dah_key(int on) {
  iambic._inDah = on;
}

static void midi_decode(int count, unsigned char *p) {
  if (count == 3) {
    switch (p[0]&0xF0) {
    case NOTE_OFF: if (p[1]&1) iambic_dah_key(0); else iambic_dit_key(0); break;
    case NOTE_ON:  if (p[1]&1) iambic_dah_key(1); else iambic_dit_key(1); break;
    }
  } else if (count > 3 && p[0] == SYSEX) {
    if (p[1] == SYSEX_VENDOR) {
      main_parse_command(&fw.opts, p+3);
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
      midi_decode(in_event.size, in_event.buffer);
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
    iambic_transition(1);
  }
  frames += 1;
  if (duration >= nframes)
    duration -= nframes;
  return 0;
}

int main(int argc, char **argv) {
  keyer_framework_main(&fw, argc, argv, "keyer_iambic", require_midi_in|require_midi_out, iambic_init, iambic_process_callback, NULL);
}
