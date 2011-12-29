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
#include <math.h>

#include <jack/jack.h>
#include <jack/midiport.h>

#include "keyer_options.h"
#include "keyer_midi.h"
#include "keyer_framework.h"

typedef struct {
  unsigned last_frame;	/* frame of last event */
  int estimate;		/* estimated dot clock period */
  unsigned n_dit;	/* number of dits estimated */
  unsigned n_dah;	/* number of dahs estimated */
  unsigned n_ies;	/* number of inter-element spaces estimated */
  unsigned n_ils;	/* number of inter-letter spaces estimated */
  unsigned n_iws;	/* number of inter-word spaces estimated */
} decode_t;

static decode_t decode = {
  0, 6000, 1, 1, 1, 1, 1
};

static keyer_framework_t fw;

unsigned frame;

/*
** The basic problem is to infer the dit clock rate from observations of dits, dahs, inter-element spaces,
** inter-letter spaces, and maybe inter-word spaces.
**
** Assume that each element observed is either a dit or a dah and record its contribution to the estimated
** dot clock as if it were both T and 3*T in length. Similarly, take each space observed as potentially
** T, 3*T, and 7*T in length.
**
** But weight the T, 3*T, and 7*T observations by the inverse of their squared distance from the current
** estimate, and weight the T, 3*T, and 7*T observations by their observed frequency in morse code.
*/
static void midi_decode(unsigned count, unsigned char *p) {
  /* decode note/channel based events */
  if (fw.opts.verbose > 4)
    fprintf(stderr, "%d: midi_decode(%x, [%x, %x, %x, ...]\n", frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == fw.opts.chan && note == fw.opts.note) {
      int observation = frame - decode.last_frame; /* length of observed element or space */
      char *out;				   /* decoded element */
      decode.last_frame = frame;
      switch (p[0]&0xF0) {
      case NOTE_OFF: /* the end of a dit or a dah */
	{
	  int o_dit = observation;			/* if it's a dit, then the length is the dit clock observation */
	  int o_dah = observation / 3;		/* if it's a dah, then the length/3 is the dit clock observation */
	  int d_dit = o_dit - decode.estimate;	/* the dit distance from the current estimate */
	  int d_dah = o_dah - decode.estimate;	/* the dah distance from the current estimate */
	  int guess = 100 * observation / decode.estimate;
	  if (d_dit == 0 || d_dah == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */
	  } else {
	    /* the weight of an observation is
	     * the observed frequency of the element
	     * scaled by inverse of distance from our current estimate
	     * normalized to one over the observations made
	     */
	    float w_dit = 1.0 * decode.n_dit / (d_dit*d_dit); /* raw weight of dit observation */
	    float w_dah = 1.0 * decode.n_dah / (d_dah*d_dah); /* raw weight of dah observation */
	    float wt = w_dit + w_dah;			      /* weight normalization */
	    int update = (o_dit * w_dit + o_dah * w_dah) / wt;
	    decode.estimate += update;
	    decode.estimate /= 2;
	    guess = 100*observation / decode.estimate;	      /* revise our guess */
	  }
	  if (guess < 200) {
	    out = "."; decode.n_dit += 1;
	  } else {
	    out = "-"; decode.n_dah += 1;
	  }
	  break;
	}
      case NOTE_ON: /* the end of an inter-element, inter-letter, or a longer space */
	{
	  int o_ies = observation;
	  int o_ils = observation / 3;
	  int d_ies = o_ies - decode.estimate;
	  int d_ils = o_ils - decode.estimate;
	  int guess = 100 * observation / decode.estimate;
	  if (d_ies == 0 || d_ils == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */	    
	  } else if (guess > 500) {
	    /* if it looks like a word space, it could be any length, don't worry about how long it is */
	  } else {
	    float w_ies = 1.0 * decode.n_ies / (d_ies*d_ies), w_ils = 1.0 * decode.n_ils / (d_ils*d_ils);
	    float wt = w_ies + w_ils;
	    int update = (o_ies * w_ies + o_ils * w_ils) / wt;
	    decode.estimate += update;
	    decode.estimate /= 2;
	    guess = 100 * observation / decode.estimate;
	  }
	  if (guess < 200) {
	    out = ""; decode.n_ies += 1;
	  } else if (guess < 500) {
	    out = " "; decode.n_ils += 1;
	  } else {
	    out = "\n"; decode.n_iws += 1;
	  }
	  break;
	}
      }
      if (fw.opts.verbose > 6) fprintf(stderr, "T=%d, M=%x, 100*O/T=%d\n", decode.estimate, p[0], 100*observation/decode.estimate);
      fprintf(stdout, "%s", out); fflush(stdout);
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

static void decode_init() {
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
  keyer_framework_main(&fw, narg, args, "keyer_decode", require_midi_in, decode_init, decode_process_callback,  NULL);
}

