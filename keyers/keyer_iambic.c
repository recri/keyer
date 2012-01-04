/** 
    Copyright (c) 2011,2012 by Roger E Critchlow Jr

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

#define OPTIONS_TIMING	1
#define OPTIONS_KEYER	1

#include "framework.h"
#include "options.h"
#include "midi.h"
#include "midi_buffer.h"
#include "timing.h"

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
  IAMBIC_OFF,			/* silent, no paddles down */
  IAMBIC_DIT,			/* sounding a dit, dit paddle down */
  IAMBIC_DIT_SPACE,		/* sounding a space after a dit */
  IAMBIC_DAH,			/* sounding a dah, dah paddle down */
  IAMBIC_DAH_SPACE,		/* sounding a space after a dah */
  IAMBIC_SYMBOL_SPACE,		/* sounding an inter-symbol space */
  IAMBIC_WORD_SPACE,		/* sounding an inter-word space */
} _state_t;

static char *_keys[] = {
  "OFF", "DAH", "DIT", "DIDAH"
};

static char *_states[] = {
  "OFF",
  "DIT", "DIT_SPACE",
  "DAH", "DAH_SPACE",
  "SYMBOL_SPACE",
  "WORD_SPACE"
};

typedef struct {
  char _modified;

  char _inDit;
  char _inDah;

  int _keyerDuration;
  char _keyIn;
  char _lastKeyIn;
  _state_t _keyerState;

  int _halfClock;
  int _halfClockCounter;
#define KEY_IN_MEM	8
  char _prevKeyIn[KEY_IN_MEM];
  unsigned _prevKeyInPtr;
} iambic_t;

typedef struct {
  framework_t fw;
  timing_t samples_per;
  unsigned char note_on[3];
  unsigned char note_off[3];
  iambic_t iambic;
  unsigned long frames;
  unsigned duration;
  options_t sent;
  midi_buffer_t midi;
} _t;

static char *preface(_t *dp, const char *file, int line) {
  static char buff[256];
  sprintf(buff, "%s:%s:%d@%ld", dp->fw.opts.client, file, line, dp->frames);
  return buff;
				 }
  
#define PREFACE	preface(dp, __FILE__, __LINE__)

// initialize the iambic keyer
static void _init(void *arg) {
  _t *dp = (_t *)arg;
  if (dp->fw.opts.verbose > 2) fprintf(stderr, "%ld: iambic_init()\n", dp->frames);
  dp->iambic._modified = 1;
  dp->iambic._inDit = 0;		/* the midi dit value */
  dp->iambic._inDah = 0;		/* the midi dah value */
  dp->iambic._keyIn = KEYIN_OFF;
  dp->iambic._lastKeyIn = KEYIN_OFF;
  dp->iambic._keyerState = IAMBIC_OFF;
  dp->duration = 0;
  midi_init(&dp->midi);
}

// update the computed parameters
static void _update(_t *dp) {
  if (dp->fw.opts.modified) {
    dp->fw.opts.modified = 0;

    if (dp->fw.opts.verbose > 2) fprintf(stderr, "%ld: recomputing data from options\n", dp->frames);

    /* timer recomputation */
    keyer_timing_update(&dp->fw.opts, &dp->samples_per);
    if (dp->fw.opts.verbose > 2) keyer_timing_report(stderr, &dp->fw.opts, &dp->samples_per);

    /* midi note on/off */
    dp->note_on[0] = NOTE_ON|(dp->fw.opts.chan-1); dp->note_on[1] = dp->fw.opts.note;
    dp->note_off[0] = NOTE_OFF|(dp->fw.opts.chan-1); dp->note_on[1] = dp->fw.opts.note;

    /* pass on parameters to tone keyer */
    char buffer[128];
    if (dp->sent.rise != dp->fw.opts.rise) { sprintf(buffer, "<rise%.1f>", dp->sent.rise = dp->fw.opts.rise); midi_sysex_write(&dp->midi, buffer); }
    if (dp->sent.fall != dp->fw.opts.fall) { sprintf(buffer, "<fall%.1f>", dp->sent.fall = dp->fw.opts.fall); midi_sysex_write(&dp->midi, buffer); }
    if (dp->sent.freq != dp->fw.opts.freq) { sprintf(buffer, "<freq%.1f>", dp->sent.freq = dp->fw.opts.freq); midi_sysex_write(&dp->midi, buffer); }
    if (dp->sent.gain != dp->fw.opts.gain) { sprintf(buffer, "<gain%.1f>", dp->sent.gain = dp->fw.opts.gain); midi_sysex_write(&dp->midi, buffer); }

    /* trigger iambic updates */
    dp->iambic._modified = 1;
  }
  if (dp->iambic._modified) {
    dp->iambic._modified = 0;
    dp->iambic._halfClock = dp->samples_per.dit / 2;
  }
}

// transition to the specified state
// with the specified duration
static char _transition_to(_t *dp, _state_t newState, unsigned newDuration) {
  if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: to %s for %d\n", dp->frames, _states[newState], newDuration);
  dp->iambic._keyerState = newState;
  dp->iambic._keyerDuration += newDuration;
  return 1;
}

// transition to the specified state
// with the specified state duration
// and send a key event with specified duration
static char _key_and_transition_to(_t *dp, _state_t newState, unsigned newDuration, char keyOut) {
  if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: key %d %x\n", dp->frames, newDuration, keyOut);
  midi_write(&dp->midi, newDuration, 3, keyOut ? dp->note_on : dp->note_off);
  return _transition_to(dp, newState, newDuration);
}

// start a dit if _dit is pressed
// or modeB && squeeze was released in last dah
static char _start_dit(_t *dp) {
  char keyIn = dp->iambic._keyIn;
  if (dp->fw.opts.mode == 'B' && dp->iambic._keyIn == KEYIN_OFF && dp->iambic._prevKeyIn[(dp->iambic._prevKeyInPtr-5) & (KEY_IN_MEM-1)] == KEYIN_DIDAH)
    keyIn = dp->iambic._prevKeyIn[(dp->iambic._prevKeyInPtr-5) & (KEY_IN_MEM-1)];
  return KEYIN_IS_DIT(keyIn) ? _key_and_transition_to(dp, IAMBIC_DIT, dp->samples_per.dit, 1) : 0;
}

// start a dah if _dah is pressed
// or modeB && squeeze was released in last dit
static char _start_dah(_t *dp) {
  char keyIn = dp->iambic._keyIn;
  if (dp->fw.opts.mode == 'B' && dp->iambic._keyIn == KEYIN_OFF && dp->iambic._prevKeyIn[(dp->iambic._prevKeyInPtr-3) & (KEY_IN_MEM-1)] == KEYIN_DIDAH)
    keyIn = dp->iambic._prevKeyIn[(dp->iambic._prevKeyInPtr-3) & (KEY_IN_MEM-1)];
  return KEYIN_IS_DAH(keyIn) ? _key_and_transition_to(dp, IAMBIC_DAH, dp->samples_per.dah, 1) : 0;
}

// continue an interelement space to an intersymbol space
// or an intersymbol space to an interword space
static char _continue_space(_t *dp, _state_t newState, unsigned newDuration) {
  if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: continue space %d\n", dp->frames, newDuration);
  midi_write(&dp->midi, newDuration, 0, "");
  return _transition_to(dp, newState, newDuration);
}

static char _symbol_space(_t *dp) {
  return dp->fw.opts.alsp ? _continue_space(dp, IAMBIC_SYMBOL_SPACE, dp->samples_per.ils-dp->samples_per.ies) : 0;
}

static char _word_space(_t *dp) {
  return dp->fw.opts.awsp ? _continue_space(dp, IAMBIC_WORD_SPACE, dp->samples_per.iws-dp->samples_per.ils) : 0;
}

// return to keyer idle state
static char _finish(_t *dp) {
  return _transition_to(dp, IAMBIC_OFF, 0L);
}

// at the beginning of the next symbol
// we may be currently at dit+dah, but
// we want to start with which ever
// paddle was pressed first
static char _start_symbol(_t *dp) {
  if (dp->iambic._keyIn != KEYIN_DIDAH || dp->iambic._lastKeyIn != KEYIN_DAH)
    return _start_dit(dp) || _start_dah(dp) ? 1 : 0;
  else
    return _start_dah(dp) || _start_dit(dp) ? 1 : 0;
}

// start an interelement space
static char _start_space(_t *dp, _state_t newState) {
  return _key_and_transition_to(dp, newState, dp->samples_per.ies, 0);
}

// process keyer state
// and generate transitions
static void iambic_transition(_t *dp, unsigned samples) {
  // construct input key state
  char keyIn = dp->fw.opts.swap ? KEYIN(dp->iambic._inDah, dp->iambic._inDit) : KEYIN(dp->iambic._inDit, dp->iambic._inDah);
  if (dp->iambic._keyIn != keyIn) {
    if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: keyIn %x\n", dp->frames, keyIn);
    dp->iambic._lastKeyIn = dp->iambic._keyIn;
  }
  dp->iambic._keyIn = keyIn;

  // start a symbol if either paddle is pressed
  if (dp->iambic._keyerState == IAMBIC_OFF) {
    _start_symbol(dp);
    dp->iambic._halfClockCounter = dp->iambic._halfClock;
    dp->iambic._prevKeyIn[dp->iambic._prevKeyInPtr++ & (KEY_IN_MEM-1)] = keyIn;
    return;
  }

  // reduce the half clock by the time elapsed
  dp->iambic._halfClockCounter -= samples;

  // if the half clock has elapsed, reset it
  if (dp->iambic._halfClockCounter < 0) {
    dp->iambic._halfClockCounter = dp->iambic._halfClock;
    dp->iambic._prevKeyIn[dp->iambic._prevKeyInPtr++ & (KEY_IN_MEM-1)] = keyIn;
  }

  // reduce the duration by the time elapsed
  dp->iambic._keyerDuration -= samples;

  // if the duration has not elapsed, return
  if (dp->iambic._keyerDuration > 0) {
    return;
  }
  
  // compute updated parameters 
  _update(dp);

  if (dp->fw.opts.verbose > 4) fprintf(stderr, "%ld: dur %d key %s state %s\n", dp->frames, dp->iambic._keyerDuration, _keys[dp->iambic._keyIn], _states[dp->iambic._keyerState]);

  // determine the next element by the current paddle state
  switch (dp->iambic._keyerState) {
  case IAMBIC_DIT: // finish the dit with an interelement space
    _start_space(dp, IAMBIC_DIT_SPACE);
    return;
  case IAMBIC_DAH: // finish the dah with an interelement space
    _start_space(dp, IAMBIC_DAH_SPACE);
    return;
  case IAMBIC_DIT_SPACE: // start the next element or finish the symbol
    _start_dah(dp) || _start_dit(dp) || _symbol_space(dp) || _finish(dp);
    return;
  case IAMBIC_DAH_SPACE: // start the next element or finish the symbol	
    _start_dit(dp) || _start_dah(dp) || _symbol_space(dp) || _finish(dp);
    return;
  case IAMBIC_SYMBOL_SPACE: // start a new symbol or finish the word
    _start_symbol(dp) || _word_space(dp) || _finish(dp);
    return;
  case IAMBIC_WORD_SPACE:  // start a new symbol or go to off
    _start_symbol(dp) || _finish(dp);
    return;
  }
}

static void _dit_key(_t *dp, int on) {
  dp->iambic._inDit = on;
}

static void _dah_key(_t *dp, int on) {
  dp->iambic._inDah = on;
}

static void _decode(_t *dp, int count, unsigned char *p) {
  if (count == 3) {
    unsigned char channel = (p[0]&0xF)+1;
    unsigned char command = p[0]&0xF0;
    unsigned char note = p[1];
    if (channel != dp->fw.opts.chan) {
      if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mychan=0x%x\n", PREFACE, channel, note, dp->fw.opts.chan, dp->fw.opts.note);
    } else if (note == dp->fw.opts.note) {
      if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
      switch (command) {
      case NOTE_OFF: _dit_key(dp, 0); break;
      case NOTE_ON:  _dit_key(dp, 1); break;
      }
    } else if (note == dp->fw.opts.note+1) {
      if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, ...])\n", PREFACE, p[0], p[1]);
      switch (command) {
      case NOTE_OFF:  _dah_key(dp, 0); break;
      case NOTE_ON:   _dah_key(dp, 1); break;
      }
    } else {
      if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode discard chan=0x%x note=0x%x != mynote=0x%x\n", PREFACE, channel, note, dp->fw.opts.chan, dp->fw.opts.note);
    }
  } else if (count > 3 && p[0] == SYSEX && p[1] == SYSEX_VENDOR) {
    if (dp->fw.opts.verbose) fprintf(stderr, "%s _decode([%x, %x, %x, ...])\n", PREFACE, p[0], p[1], p[2]);
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
    // in_event_time += in_event.time;
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
      if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: process event %x [%x, %x, %x, ...]\n", dp->frames, (unsigned)in_event.size, in_event.buffer[0], in_event.buffer[1], in_event.buffer[2]);
      _decode(dp, in_event.size, in_event.buffer);
      if (in_event_index < in_event_count) {
	jack_midi_event_get(&in_event, midi_in, in_event_index++);
	// in_event_time += in_event.time;
	in_event_time = in_event.time;
      } else {
	in_event_time = nframes+1;
      }
    }
    /* process all midi output events at this sample frame */
    while (dp->duration == i) {
      if (midi_readable(&dp->midi)) {
	if (dp->fw.opts.verbose > 4) fprintf(stderr, "%ld: midi_readable, duration %u, count %u\n", dp->frames, midi_duration(&dp->midi), midi_count(&dp->midi));
	dp->duration += midi_duration(&dp->midi);
	unsigned count = midi_count(&dp->midi);
	if (count != 0) {
	  unsigned char* buffer = jack_midi_event_reserve(midi_out, i, count);
	  if (buffer == NULL) {
	    fprintf(stderr, "%ld: jack won't buffer %d midi bytes!\n", dp->frames, count);
	  } else {
	    midi_read_bytes(&dp->midi, count, buffer);
	    if (dp->fw.opts.verbose > 5) fprintf(stderr, "%ld: sent %x [%x, %x, %x, ...]\n", dp->frames, count, buffer[0], buffer[1], buffer[2]);
	  }
	}
	midi_read_next(&dp->midi);
      } else {
	dp->duration = nframes;
      }
    }
    /* clock the iambic keyer */
    iambic_transition(dp, 1);
  }
  dp->frames += 1;
  if (dp->duration >= nframes)
    dp->duration -= nframes;
  return 0;
}

#if AS_BIN
int main(int argc, char **argv) {
  _t data;
  framework_main((void *)&data, argc, argv, "keyer_iambic", 0,0,1,1, _init, _process, NULL);
}
#endif

#if AS_TCL
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  _update(clientData);
  return TCL_OK;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, 0,0,1,1, _command, _process, sizeof(_t), _init, NULL, "config|cget");
}

int DLLEXPORT Keyer_iambic_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer", "1.0.0", "keyer::iambic", _factory);
}
#endif
