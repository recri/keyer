/*
  Copyright (C) 2011 Roger E Critchlow Jr, rec@elf.org

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

#define OPTIONS_TONE 1

#include "framework.h"
#include "options.h"
#include "midi.h"

#include <math.h>

#include "osc.h"
#include "ramp.h"

// On Intel set FZ (Flush to Zero) and DAZ (Denormals Are Zero) flags to avoid costly denormals
#ifdef __SSE__
    #include <xmmintrin.h>
    #ifdef __SSE2__
        #define AVOIDDENORMALS _mm_setcsr(_mm_getcsr() | 0x8040)
    #else
        #define AVOIDDENORMALS _mm_setcsr(_mm_getcsr() | 0x8000)
    #endif
#else
    #define AVOIDDENORMALS 
#endif

/*
** cw tone
** generates a tone with specified frequency and gain
** with sine ramped attack and decay
*/

#define CWTONE_OFF	0	/* note is not sounding */
#define CWTONE_RISE	1	/* note is ramping up to full level */
#define CWTONE_ON	2	/* note is sounding full level */
#define CWTONE_FALL	3	/* note is ramping down to off */

typedef struct {
  int state;			/* state of cwtone */
  float gain;			/* target gain */
  osc_t tone;			/* tone oscillator */
  ramp_t rise;			/* tone on ramp */
  ramp_t fall;			/* tone off ramp */
} cwtone_t;

typedef struct {
  framework_t fw;
  cwtone_t cwtone;
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
    dp->cwtone.gain = pow(10.0, dp->fw.opts.gain / 20.0);
    osc_update(&dp->cwtone.tone, dp->fw.opts.freq, dp->fw.opts.sample_rate);
    ramp_update(&dp->cwtone.rise, dp->fw.opts.rise, dp->fw.opts.sample_rate);
    ramp_update(&dp->cwtone.fall, dp->fw.opts.fall, dp->fw.opts.sample_rate);
  }
}

static void cwtone_init(_t *dp) {
  if (dp->fw.opts.verbose) fprintf(stderr, "%s:%s:%d cwtone_init\n", dp->fw.opts.client, __FILE__, __LINE__);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init freq %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.freq);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init gain %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.gain);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init rise %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.rise);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init fall %.1f\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.fall);
  if (dp->fw.opts.verbose > 1) fprintf(stderr, "%s:%s:%d cwtone_init rate %d\n", dp->fw.opts.client, __FILE__, __LINE__, dp->fw.opts.sample_rate);
  dp->cwtone.state = CWTONE_OFF;
  dp->cwtone.gain = pow(10.0, dp->fw.opts.gain / 20.0);
  osc_init(&dp->cwtone.tone, dp->fw.opts.freq, dp->fw.opts.sample_rate);
  ramp_init(&dp->cwtone.rise, dp->fw.opts.rise, dp->fw.opts.sample_rate);
  ramp_init(&dp->cwtone.fall, dp->fw.opts.fall, dp->fw.opts.sample_rate);
}

static void cwtone_on(_t *dp) {
  dp->cwtone.state = CWTONE_RISE;
  ramp_reset(&dp->cwtone.rise);
}

static void cwtone_off(_t *dp) {
  dp->cwtone.state = CWTONE_FALL;
  ramp_reset(&dp->cwtone.fall);
}

static void cwtone_xy(_t *dp, float *x, float *y) {
  float scale = dp->cwtone.gain;
  switch (dp->cwtone.state) {
  case CWTONE_OFF:	/* note is not sounding */
    scale = 0;
    break;
  case CWTONE_RISE:	/* note is ramping up to full level */
    scale *= ramp_next(&dp->cwtone.rise);
    if (ramp_done(&dp->cwtone.rise))
      dp->cwtone.state = CWTONE_ON;
    break;
  case CWTONE_ON:	/* note is sounding full level */
    break;
  case CWTONE_FALL:	/* note is ramping down to off */
    scale *= 1-ramp_next(&dp->cwtone.fall);
    if (ramp_done(&dp->cwtone.fall))
      dp->cwtone.state = CWTONE_OFF;
    break;
  }
  osc_next_xy(&dp->cwtone.tone, x, y);
  *x *= scale;
  *y *= scale;
}

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
      case NOTE_OFF: cwtone_off(dp); break;
      case NOTE_ON:  cwtone_on(dp); break;
      }
    else if (dp->fw.opts.verbose > 3)
      fprintf(stderr, "discarded midi chan=0x%x note=0x%x != mychan=0x%x mynote=0x%x\n", channel, note, dp->fw.opts.chan, dp->fw.opts.note);
  } else if (count > 3 && p[0] == SYSEX) {
    if (p[1] == SYSEX_VENDOR) {
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
  cwtone_update(dp);
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
    AVOIDDENORMALS;
    cwtone_xy(dp, out_i+i, out_q+i);
    /* increment frame counter */
    dp->frame += 1;
  }
  return 0;
}

#if AS_BIN
int main(int narg, char **args) {
  _t data;
  framework_main((void *)&data, narg, args, "keyer_tone", 0,2,1,0, _init, _process, NULL);
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
  return framework_factory(clientData, interp, argc, objv, 0,2,1,0, _command, _process, sizeof(_t), _init, NULL, "config|cget");
}

int DLLEXPORT Keyer_tone_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer", "1.0.0", "keyer::tone", _factory);
}
#endif

