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

#include "framework.h"
#include "options.h"
#include "midi.h"

typedef struct {
  unsigned last_frame;	/* frame of last event */
  int estimate;		/* estimated dot clock period */
  unsigned n_dit;	/* number of dits estimated */
  unsigned n_dah;	/* number of dahs estimated */
  unsigned n_ies;	/* number of inter-element spaces estimated */
  unsigned n_ils;	/* number of inter-letter spaces estimated */
  unsigned n_iws;	/* number of inter-word spaces estimated */
} decode_t;

typedef struct {
  framework_t fw;
  decode_t decode;
  unsigned frame;
  /* Tcl needs a ring buffer to store decoded elements */
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
static void _decode(_t *dp, unsigned count, unsigned char *p) {
  /* decode note/channel based events */
  if (dp->fw.opts.verbose > 4)
    fprintf(stderr, "%d: midi_decode(%x, [%x, %x, %x, ...]\n", dp->frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    char channel = (p[0]&0xF)+1;
    char note = p[1];
    if (channel == dp->fw.opts.chan && note == dp->fw.opts.note) {
      int observation = dp->frame - dp->decode.last_frame; /* length of observed element or space */
      char *out;				   /* decoded element */
      dp->decode.last_frame = dp->frame;
      switch (p[0]&0xF0) {
      case NOTE_OFF: /* the end of a dit or a dah */
	{
	  int o_dit = observation;			/* if it's a dit, then the length is the dit clock observation */
	  int o_dah = observation / 3;		/* if it's a dah, then the length/3 is the dit clock observation */
	  int d_dit = o_dit - dp->decode.estimate;	/* the dit distance from the current estimate */
	  int d_dah = o_dah - dp->decode.estimate;	/* the dah distance from the current estimate */
	  int guess = 100 * observation / dp->decode.estimate;
	  if (d_dit == 0 || d_dah == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */
	  } else {
	    /* the weight of an observation is
	     * the observed frequency of the element
	     * scaled by inverse of distance from our current estimate
	     * normalized to one over the observations made
	     */
	    float w_dit = 1.0 * dp->decode.n_dit / (d_dit*d_dit); /* raw weight of dit observation */
	    float w_dah = 1.0 * dp->decode.n_dah / (d_dah*d_dah); /* raw weight of dah observation */
	    float wt = w_dit + w_dah;			      /* weight normalization */
	    int update = (o_dit * w_dit + o_dah * w_dah) / wt;
	    dp->decode.estimate += update;
	    dp->decode.estimate /= 2;
	    guess = 100*observation / dp->decode.estimate;	      /* revise our guess */
	  }
	  if (guess < 200) {
	    out = "."; dp->decode.n_dit += 1;
	  } else {
	    out = "-"; dp->decode.n_dah += 1;
	  }
	  break;
	}
      case NOTE_ON: /* the end of an inter-element, inter-letter, or a longer space */
	{
	  int o_ies = observation;
	  int o_ils = observation / 3;
	  int d_ies = o_ies - dp->decode.estimate;
	  int d_ils = o_ils - dp->decode.estimate;
	  int guess = 100 * observation / dp->decode.estimate;
	  if (d_ies == 0 || d_ils == 0) {
	    /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */	    
	  } else if (guess > 500) {
	    /* if it looks like a word space, it could be any length, don't worry about how long it is */
	  } else {
	    float w_ies = 1.0 * dp->decode.n_ies / (d_ies*d_ies), w_ils = 1.0 * dp->decode.n_ils / (d_ils*d_ils);
	    float wt = w_ies + w_ils;
	    int update = (o_ies * w_ies + o_ils * w_ils) / wt;
	    dp->decode.estimate += update;
	    dp->decode.estimate /= 2;
	    guess = 100 * observation / dp->decode.estimate;
	  }
	  if (guess < 200) {
	    out = ""; dp->decode.n_ies += 1;
	  } else if (guess < 500) {
	    out = " "; dp->decode.n_ils += 1;
	  } else {
	    out = "\n"; dp->decode.n_iws += 1;
	  }
	  break;
	}
      }
      if (dp->fw.opts.verbose > 6) fprintf(stderr, "T=%d, M=%x, 100*O/T=%d\n", dp->decode.estimate, p[0], 100*observation/dp->decode.estimate);
#if AS_BIN
      fprintf(stdout, "%s", out); fflush(stdout);
#endif
#if AS_TCL
      
#endif
    } else if (dp->fw.opts.verbose > 3)
      fprintf(stderr, "discarded midi chan=0x%x note=0x%x != mychan=0x%x mynote=0x%x\n", channel, note, dp->fw.opts.chan, dp->fw.opts.note);
  } else if (count > 3 && p[0] == SYSEX) {
    if (p[1] == SYSEX_VENDOR) {
      options_parse_command(&dp->fw.opts, p+3);
      if (dp->fw.opts.verbose > 3)
	fprintf(stderr, "sysex: %*s\n", count, p+2);
    }
  }
}

static void _init(void *arg) {
  _t *dp = (_t *)arg;
  dp->decode = (decode_t){ 0, 6000, 1, 1, 1, 1, 1 };
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
    /* increment the frame counter */
    dp->frame += 1;
  }
  return 0;
}

#if AS_BIN
int main(int narg, char **args) {
  _t data;
  framework_main((void *)&data, narg, args, "keyer_decode", 0,0,1,0, _init, _process,  NULL);
}
#endif

#if AS_TCL
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 2 && strcmp(Tcl_GetString(objv[1]), "gets") == 0) {
    // return the current decoded string
    return TCL_OK;
  }
  if (framework_command(clientData, interp, argc, objv) != TCL_OK)
    return TCL_ERROR;
  // _update(clientData);
  return TCL_OK;
}

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, 0,0,1,0, _command, _process, sizeof(_t), _init, NULL, "config|cget|cdoc|gets");
}

int DLLEXPORT Keyer_decode_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer", "1.0.0", "keyer::decode", _factory);
}
#endif
