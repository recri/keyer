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

  keyer_decode reads midi note on and note off, infers a dit clock,
  and produces a string of dits, dahs, and spaces.
    
  It currently gets confused if it starts on something that's all
  dah's and spaces, so I'm cheating and sending the wpm from the
  keyers.  It should wait until it's seen both dits and dahs before
  making its first guesses.

*/

#define KEYER_OPTIONS_TIMING	1

#include "framework.h"
#include "../sdrkit/midi.h"
#include "../sdrkit/ring_buffer.h"

typedef struct {
#include "keyer_options_var.h"
} options_t;
  
typedef struct {
  unsigned last_frame;	/* frame of last event */
  int estimate;		/* estimated dot clock period */
  unsigned n_dit;	/* number of dits estimated */
  unsigned n_dah;	/* number of dahs estimated */
  unsigned n_ies;	/* number of inter-element spaces estimated */
  unsigned n_ils;	/* number of inter-letter spaces estimated */
  unsigned n_iws;	/* number of inter-word spaces estimated */
} detime_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  detime_t detime;
  unsigned frame;
  #define RING_SIZE 512
  ring_buffer_t ring;
  unsigned char buff[RING_SIZE];
} _t;

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
static void _detime(_t *dp, unsigned count, unsigned char *p) {
  /* detime note/channel based events */
  if (dp->opts.verbose > 4)
    fprintf(stderr, "%d: midi_detime(%x, [%x, %x, %x, ...]\n", dp->frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == dp->opts.chan && note == dp->opts.note) {
      int observation = dp->frame - dp->detime.last_frame; /* length of observed element or space */
      char *out;				   /* detimed element */
      dp->detime.last_frame = dp->frame;
      switch (p[0]&0xF0) {
      case MIDI_NOTE_OFF: /* the end of a dit or a dah */
	{
	  int o_dit = observation;			/* if it's a dit, then the length is the dit clock observation */
	  int o_dah = observation / 3;			/* if it's a dah, then the length/3 is the dit clock observation */
	  int d_dit = o_dit - dp->detime.estimate;	/* the dit distance from the current estimate */
	  int d_dah = o_dah - dp->detime.estimate;	/* the dah distance from the current estimate */
	  int guess = 100 * observation / dp->detime.estimate;
	  if (d_dit == 0 || d_dah == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */
	  } else {
	    /* the weight of an observation is
	     * the observed frequency of the element
	     * scaled by inverse of distance from our current estimate
	     * normalized to one over the observations made
	     */
	    float w_dit = 1.0 * dp->detime.n_dit / (d_dit*d_dit); /* raw weight of dit observation */
	    float w_dah = 1.0 * dp->detime.n_dah / (d_dah*d_dah); /* raw weight of dah observation */
	    float wt = w_dit + w_dah;				  /* weight normalization */
	    int update = (o_dit * w_dit + o_dah * w_dah) / wt;
	    dp->detime.estimate += update;
	    dp->detime.estimate /= 2;
	    guess = 100*observation / dp->detime.estimate;	  /* revise our guess */
	  }
	  if (guess < 200) {
	    out = "."; dp->detime.n_dit += 1;
	  } else {
	    out = "-"; dp->detime.n_dah += 1;
	  }
	  break;
	}
      case MIDI_NOTE_ON: /* the end of an inter-element, inter-letter, or a longer space */
	{
	  int o_ies = observation;
	  int o_ils = observation / 3;
	  int d_ies = o_ies - dp->detime.estimate;
	  int d_ils = o_ils - dp->detime.estimate;
	  int guess = 100 * observation / dp->detime.estimate;
	  if (d_ies == 0 || d_ils == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */	    
	  } else if (guess > 500) {
	    /* if it looks like a word space, it could be any length, don't worry about how long it is */
	  } else {
	    float w_ies = 1.0 * dp->detime.n_ies / (d_ies*d_ies), w_ils = 1.0 * dp->detime.n_ils / (d_ils*d_ils);
	    float wt = w_ies + w_ils;
	    int update = (o_ies * w_ies + o_ils * w_ils) / wt;
	    dp->detime.estimate += update;
	    dp->detime.estimate /= 2;
	    guess = 100 * observation / dp->detime.estimate;
	  }
	  if (guess < 200) {
	    out = ""; dp->detime.n_ies += 1;
	  } else if (guess < 500) {
	    out = " "; dp->detime.n_ils += 1;
	  } else {
	    out = "\n"; dp->detime.n_iws += 1;
	  }
	  break;
	}
      }
      if (dp->opts.verbose > 6) fprintf(stderr, "T=%d, M=%x, 100*O/T=%d\n", dp->detime.estimate, p[0], 100*observation/dp->detime.estimate);
      if (ring_buffer_writeable(&dp->ring)) {
	if (*out != 0)
	  ring_buffer_put(&dp->ring, 1, out);
      } else {
	fprintf(stderr, "keyer_detime: buffer overflow writing \"%s\"\n", out);
      }
    } else if (dp->opts.verbose > 3)
      fprintf(stderr, "discarded midi chan=0x%x note=0x%x != mychan=0x%x mynote=0x%x\n", channel, note, dp->opts.chan, dp->opts.note);
  } else if (count > 3 && p[0] == MIDI_SYSEX) {
    if (p[1] == MIDI_SYSEX_VENDOR) {
      // FIX.ME options_parse_command(&dp->opts, p+3);
      if (dp->opts.verbose > 3)
	fprintf(stderr, "sysex: %*s\n", count, p+2);
      dp->modified = 1;
    }
  }
}

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;
    dp->detime.estimate = (sdrkit_sample_rate(dp) * 60) / (dp->opts.wpm * dp->opts.word);
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  void *p = ring_buffer_init(&dp->ring, RING_SIZE, dp->buff); if (p != &dp->ring) return p;
  dp->detime = (detime_t){ 0, 6000, 1, 1, 1, 1, 1 };
  return arg;
}

/*
** Jack
*/

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void* midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
  jack_midi_event_t in_event;
  jack_nframes_t event_count = jack_midi_get_event_count(midi_in), event_index = 0, event_time = 0;
  /* initialize */
  if (event_index < event_count) {
    jack_midi_event_get(&in_event, midi_in, event_index++);
    // event_time += in_event.time;
    event_time = in_event.time;
  } else {
    event_time = nframes+1;
  }
  _update(dp);
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    while (event_time == i) {
      _detime(dp, in_event.size, in_event.buffer);
      if (event_index < event_count) {
	jack_midi_event_get(&in_event, midi_in, event_index++);
	// event_time += in_event.time;
	event_time = in_event.time;
      } else {
	event_time = nframes+1;
      }
    }
    /* increment the frame counter */
    dp->frame += 1;
  }
  return 0;
}

static int _gets(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // return the current detimed string
  _t *dp = (_t *)clientData;
  // hmm, how to avoid the buffer here, allocate a byte array?
  unsigned n = ring_buffer_items_available_to_read(&dp->ring);
  // fprintf(stderr, "%s:%d %u bytes available\n", __FILE__, __LINE__, n);
  Tcl_Obj *result = Tcl_NewObj();
  char *buff = Tcl_SetByteArrayLength(result, n);
  ring_buffer_get(&dp->ring, n, buff);
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.word != save.word || data->opts.wpm != save.wpm);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
#include "keyer_options_def.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "gets",	 _gets, "get the currently converted string of dits and dahs" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  0, 0, 1, 0,			// inputs,outputs,midi_inputs,midi_outputs
  "a component which converts midi key on/off events to dits and dahs"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_detime_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::detime", "1.0.0", "keyer::detime", _factory);
}
