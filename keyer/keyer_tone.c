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

  keyer_tone generates an I/Q sine tone keyed by midi events.

  Based on jack-1.9.8/example-clients/midisine.c
  and from dttsp-cgran-r624/src/cwtones.c

    - support multiple notes
    - support aftertouch
    - use sine/cosine recursion
    - output I/Q signal
    
  jack-1.9.8/example-clients/midisine.c

    Copyright (C) 2004 Ian Esten

  dttsp-cgran-r624/src/cwtones.c

    Copyright (C) 2005, 2006, 2007 by Frank Brickle, AB2KT and Bob McGwier, N4HY
    Doxygen comments added by Dave Larsen, KV0S

*/

#define OPTIONS_TONE 1
#define OPTIONS_TIMING 1

#include "framework.h"
#include "options.h"
#include "../dspkit/midi.h"

#include "../dspkit/avoid_denormals.h"
#include "../dspkit/keyed_tone.h"

typedef struct {
  framework_t fw;
  keyed_tone_t tone;
  unsigned long frame;
} _t;

static void cwtone_update(_t *dp) {
  if (dp->fw.opts.modified) {
    if (dp->fw.opts.verbose) fprintf(stderr, "%s:%s:%d cwtone_update\n", dp->fw.opts.client, __FILE__, __LINE__);
    if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_update freq %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.freq);
    if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_update gain %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.gain);
    if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_update rise %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.rise);
    if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_update fall %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.fall);
    if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_update rate %d\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.sample_rate);
    dp->fw.opts.modified = 0;
    keyed_tone_update(&dp->tone, dp->fw.opts.gain, dp->fw.opts.freq, dp->fw.opts.rise, dp->fw.opts.fall, dp->fw.opts.sample_rate);
  }
}

static void cwtone_init(_t *dp) {
  if (dp->fw.opts.verbose) fprintf(stderr, "%s:%s:%d cwtone_init\n", dp->fw.opts.client, __FILE__, __LINE__);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init freq %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.freq);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init gain %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.gain);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init rise %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.rise);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init fall %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.fall);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init rate %d\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.sample_rate);
  keyed_tone_init(&dp->tone, dp->fw.opts.gain, dp->fw.opts.freq, dp->fw.opts.rise, dp->fw.opts.fall, dp->fw.opts.sample_rate);
}

static void cwtone_on(_t *dp) { keyed_tone_on(&dp->tone); }

static void cwtone_off(_t *dp) { keyed_tone_off(&dp->tone); }

static void cwtone_xy(_t *dp, float *x, float *y) { keyed_tone_xy(&dp->tone, x, y); }

/*
** decode midi commands
*/
static void _decode(_t *dp, unsigned count, unsigned char *p) {
  /* decode note/channel based events */
  if (dp->fw.opts.verbose > 4)
    fprintf(stderr, "%s:%s:%d @%ld _decode(%x, [%x, %x, %x, ...]\n", dp->fw.opts.client, __FILE__, __LINE__, dp->frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == dp->fw.opts.chan && note == dp->fw.opts.note)
      switch (p[0]&0xF0) {
      case MIDI_NOTE_OFF: cwtone_off(dp); break;
      case MIDI_NOTE_ON:  cwtone_on(dp); break;
      }
    else if (dp->fw.opts.verbose > 3)
      fprintf(stderr, "discarded midi chan=0x%x note=0x%x != mychan=0x%x mynote=0x%x\n", channel, note, dp->fw.opts.chan, dp->fw.opts.note);
  } else if (count > 3 && p[0] == MIDI_SYSEX) {
    if (p[1] == MIDI_SYSEX_VENDOR) {
      options_parse_command(&dp->fw.opts, p+3);
      if (dp->fw.opts.verbose > 3)
	fprintf(stderr, "%s:%s:%d sysex: %*s\n", dp->fw.opts.client, __FILE__, __LINE__, count, p+2);
    }
  }
}

static void _init(void *arg) {
  _t *dp = (_t *) arg;
  cwtone_init(dp);
}

static void _update(void *arg) {
  _t *dp = (_t *) arg;
  cwtone_update(dp);
}

/*
** Jack process callback
*/
static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void* midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
  jack_default_audio_sample_t *out_i = (jack_default_audio_sample_t *) jack_port_get_buffer(framework_output(dp,0), nframes);
  jack_default_audio_sample_t *out_q = (jack_default_audio_sample_t *) jack_port_get_buffer(framework_output(dp,1), nframes);
  jack_midi_event_t in_event;
  jack_nframes_t event_count = jack_midi_get_event_count(midi_in), event_index = 0, event_time = 0;
  if (event_index < event_count) {
    jack_midi_event_get(&in_event, midi_in, event_index++);
    // event_time += in_event.time;
    event_time = in_event.time;
  } else {
    event_time = nframes+1;
  }
  /* implement updated options */
  cwtone_update(dp);
  /* avoid denormalized numbers */
  AVOID_DENORMALS;
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    while (event_time == i) {
      _decode(dp, in_event.size, in_event.buffer);
      if (event_index < event_count) {
	jack_midi_event_get(&in_event, midi_in, event_index++);
	// event_time += in_event.time;
	event_time = in_event.time;
      } else {
	event_time = nframes+1;
      }
    }
    /* compute samples for all sounding notes at this sample time */
    cwtone_xy(dp, out_i+i, out_q+i);
    /* increment frame counter */
    dp->frame += 1;
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  _update(clientData);
  return TCL_OK;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, 0,2,1,0, _command, _process, sizeof(_t), _init, NULL, "config|cget");
}

int DLLEXPORT Keyer_tone_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer", "1.0.0", "keyer::tone", _factory);
}

