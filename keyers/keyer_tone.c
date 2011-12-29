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

#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <math.h>

#include <jack/jack.h>
#include <jack/midiport.h>

#include "keyer_options.h"
#include "keyer_midi.h"
#include "keyer_osc.h"
#include "keyer_ramp.h"
#include "keyer_framework.h"

static keyer_framework_t fw;

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

#define CWTONE_NOT_INIT	-1	/* not initialized */
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

static void cwtone_set_gain(cwtone_t *cw, float gain) {
  cw->gain = pow(10.0, gain / 20.0);
}
  
static void cwtone_update(cwtone_t *cw) {
  if (fw.opts.modified) {
    fw.opts.modified = 0;
    cw->gain = pow(10.0, fw.opts.gain / 20.0);
    osc_update(&cw->tone, fw.opts.freq, fw.opts.sample_rate);
    ramp_update(&cw->rise, fw.opts.rise, fw.opts.sample_rate);
    ramp_update(&cw->fall, fw.opts.fall, fw.opts.sample_rate);
  }
  if (cw->state == CWTONE_NOT_INIT) {
    cw->state = CWTONE_OFF;
    cw->gain = pow(10.0, fw.opts.gain / 20.0);
    osc_init(&cw->tone, fw.opts.freq, fw.opts.sample_rate);
    ramp_init(&cw->rise, fw.opts.rise, fw.opts.sample_rate);
    ramp_init(&cw->fall, fw.opts.fall, fw.opts.sample_rate);
  }
}

static void cwtone_on(cwtone_t *cw) {
  cw->state = CWTONE_RISE;
  ramp_reset(&cw->rise);
}

static void cwtone_off(cwtone_t *cw) {
  cw->state = CWTONE_FALL;
  ramp_reset(&cw->fall);
}

static void cwtone_xy(cwtone_t *cw, float *x, float *y) {
  float scale = cw->gain;
  switch (cw->state) {
  case CWTONE_OFF:	/* note is not sounding */
    scale = 0;
    break;
  case CWTONE_RISE:	/* note is ramping up to full level */
    scale *= ramp_next(&cw->rise);
    if (ramp_done(&cw->rise))
      cw->state = CWTONE_ON;
    break;
  case CWTONE_ON:	/* note is sounding full level */
    break;
  case CWTONE_FALL:	/* note is ramping down to off */
    scale *= 1-ramp_next(&cw->fall);
    if (ramp_done(&cw->fall))
      cw->state = CWTONE_OFF;
    break;
  }
  osc_next_xy(&cw->tone, x, y);
  *x *= scale;
  *y *= scale;
}

static cwtone_t cwtone = { CWTONE_NOT_INIT };
static unsigned long frame;
/*
** decode midi commands
*/
static void midi_decode(unsigned count, unsigned char *p) {
  /* decode note/channel based events */
  if (fw.opts.verbose > 4)
    fprintf(stderr, "%ld: midi_decode(%x, [%x, %x, %x, ...]\n", frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == fw.opts.chan && note == fw.opts.note)
      switch (p[0]&0xF0) {
      case NOTE_OFF: cwtone_off(&cwtone); break;
      case NOTE_ON:  cwtone_on(&cwtone); break;
      }
    else if (fw.opts.verbose > 3)
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
** Jack process callback
*/
static int tone_process_callback(jack_nframes_t nframes, void *arg) {
  void* midi_in = jack_port_get_buffer(fw.midi_in, nframes);
  jack_default_audio_sample_t *out_i = (jack_default_audio_sample_t *) jack_port_get_buffer (fw.out_i, nframes);
  jack_default_audio_sample_t *out_q = (jack_default_audio_sample_t *) jack_port_get_buffer (fw.out_q, nframes);
  jack_midi_event_t in_event;
  jack_nframes_t event_count = jack_midi_get_event_count(midi_in), event_index = 0, event_time = 0;
  if (event_index < event_count) {
    jack_midi_event_get(&in_event, midi_in, event_index++);
    event_time += in_event.time;
  } else {
    event_time = nframes+1;
  }
  cwtone_update(&cwtone);
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
    /* compute samples for all sounding notes at this sample time */
    AVOIDDENORMALS;
    cwtone_xy(&cwtone, out_i+i, out_q+i);
    /* increment frame counter */
    frame += 1;
  }
  return 0;
}

int main(int narg, char **args) {
  keyer_framework_main(&fw, narg, args, "keyer_tone", require_midi_in|require_out_i|require_out_q, tone_process_callback, NULL);
}

