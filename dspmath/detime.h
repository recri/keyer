/* -*- mode: c++; tab-width: 8 -*- */
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
#ifndef DETIME_H
#define DETIME_H

/*
** Still unhappy with this, it reverts to a slower speed when left to sit
** for any length of time so every first element scores as a dah.  So you 
** decode HHHHH, wait a few moments, send another H and it comes out as B.
** Which is puzzling, since there's nothing that updates twodot in the
** absence of any received elements.
**
** Strictly, my previous attempt was correct.  Each received mark or space
** is either a sample of 1 dot clock, or 3 dot clocks, or something longer.
** As soon as you've seen examples of both, then one interpretation becomes
** untenable.
*/
#include "filter_moving_average16.h"

// these are a mixture of values for 
// detime_t.state and the event parameter to detime_process
#define DETIME_OFF 0		// key off 
#define DETIME_ON  1		// key on
#define DETIME_QUERY 2		// if key off then maybe end char
#define DETIME_RESET 3		// 
#define DETIME_IDLE 4		// then maybe send space
#define DETIME_IDLE2 5		// 

/*
** from observations of on/off events
** deduce the CW timing of the morse being received
** and start translating the marks and spaces into
** dits, dahs, inter-symbol spaces, and inter-word spaces
**
*/
typedef struct {
  unsigned spd;			// estimated samples per dot
} detime_options_t;

typedef struct {
  unsigned state;		// is key on or off
  unsigned frame;		// frame time of last event
  unsigned last_element;	// duration of last mark element
  unsigned two_dot;		// estimated duration of two dots 
  filter_moving_average16_t avg; // avg of last 16 two_dot observations
} detime_t;

// (samples per dot) =  (samples per second) / ((words per minute) * (seconds per minute) * (dots per word))
static void detime_configure(detime_t *p, detime_options_t *q) {
  p->state = DETIME_IDLE;
  p->last_element = 0;
  filter_moving_average16_init(&p->avg);
  p->two_dot = filter_moving_average16_process(&p->avg, 2 * q->spd);
}

static void *detime_preconfigure(detime_t *p, detime_options_t *q) {
  if (q->spd == 0) return (void *)"samples per dot must be positive";
  return p;
}

static void *detime_init(detime_t *p, detime_options_t *q) {
  void *e = detime_preconfigure(p, q); if (e != p) return e;
  detime_configure(p, q);
  return p;
}

/*
** The basic problem is to infer the dot clock from observations.
**
** We track the incoming dot clock by the method of fldigi-4.1.09/src/cw_rtty/cw.cxx,
** we look for adjacent keyed on elements which are roughly in duration 1:3 or 3:1,
** take the sum of their durations as 4 dot clocks, and maintain a moving average.
** 
** We keep two_dot, the number of samples in two dots, because it is the
** boundary between dit and dah and between interelement and interletter
** spacing.
**
*/
static char detime_process(detime_t *dp, int event, jack_nframes_t frame) {
  unsigned observation = frame - dp->frame; /* duration since last transition */
  switch (event) {

  case DETIME_OFF: {		/* the end of a dit or a dah */
				// error if dp->state is wrong, should be DETIME_ON
				// ignore if its a runt pulse
    dp->frame = frame;
    if (dp->last_element) {
      if ( ((observation > 2 * dp->last_element) && (observation < 4 * dp->last_element)) ||
	   ((dp->last_element > 2 * observation) && (dp->last_element < 4 * observation)) ) {
	dp->two_dot = filter_moving_average16_process(&dp->avg, (observation+dp->last_element)/2);
      }
    }
    dp->last_element = observation;
    dp->state = DETIME_OFF;
    return (observation <= dp->two_dot) ? '.' : '-';
  }

  case DETIME_ON:		/* the end of a space */
				// error if dp->state is wrong, should be DETIME_OFF or DETIME_IDLE*
    dp->frame = frame;
    dp->state = DETIME_ON;
    return 0;

  case DETIME_QUERY:		/* an intermediate tick */
    switch (dp->state) {
    case DETIME_ON:		// inside element
      return 0;
    case DETIME_OFF:		// after element end
      if (observation > dp->two_dot) {
	dp->state = DETIME_IDLE;
	return ' ';		// decode letter
      }
      return 0;			// wait some more
    case DETIME_IDLE:
      if (observation > 3*dp->two_dot) {
	dp->state = DETIME_IDLE2;
	return ' ';		// insert word space
      }
      return 0;			// wait some more
    case DETIME_IDLE2:
      return 0;
    default:
      fprintf(stderr, "detime_process: invalid state %d in query\n", dp->state);
      return 0;
    }

  case DETIME_RESET:
    fprintf(stderr, "detime_process: reset event\n");
    return 0;

  default: 
    fprintf(stderr, "detime_process: invalid event %d\n", event);
    return 0;
  }
}
#endif
