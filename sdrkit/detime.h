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
** from observations of on/off events
** deduce the CW timing of the morse being received
** and start translating the marks and spaces into
** dits, dahs, inter-symbol spaces, and inter-word spaces
*/
typedef struct {
  float wpm, word, estimate;
  jack_nframes_t sample_rate;
} detime_options_t;

typedef struct {
  unsigned frame;	/* frame time of last event */
  unsigned n_dit;	/* number of dits estimated */
  unsigned n_dah;	/* number of dahs estimated */
  unsigned n_ies;	/* number of inter-element spaces estimated */
  unsigned n_ils;	/* number of inter-letter spaces estimated */
  unsigned n_iws;	/* number of inter-word spaces estimated */
  int estimate;		/* estimated dot clock period */
  jack_nframes_t sample_rate;
} detime_t;

static void detime_configure(detime_t *p, detime_options_t *q) {
  p->estimate = q->estimate;
  p->sample_rate = q->sample_rate;
}

static void *detime_preconfigure(detime_t *p, detime_options_t *q) {
  if (q->wpm <= 0) return (void *)"words per minute must be positive";
  if (q->word <= 0) return (void *)"dits per word must be positive";
  if (q->sample_rate <= 0) return (void *)"samples per second must be positive";
  q->estimate = (q->sample_rate * 60) / (q->wpm * q->word);
  return p;
}

static void *detime_init(detime_t *p, detime_options_t *q) {
  void *e = detime_preconfigure(p, q); if (e != p) return e;
  detime_configure(p, q);
  return p;
}

/*
** The basic problem is to infer the dit clock rate from observations of dits,
** dahs, inter-element spaces, inter-letter spaces, and maybe inter-word spaces.
**
** Assume that each element observed is either a dit or a dah and record its
** contribution to the estimated dot clock as if it were both T and 3*T in length.
** Similarly, take each space observed as potentially T, 3*T, and 7*T in length.
**
** But weight the T, 3*T, and 7*T observations by the inverse of their squared
** distance from the current estimate, and weight the T, 3*T, and 7*T observations
** by their observed frequency in morse code.
**
** Until detime has seen both dits and dahs, it will be a little confused.
*/
static char detime_process(detime_t *dp, int onoff, jack_nframes_t frame) {
  int observation = frame - dp->frame; /* length of observed element or space */
  dp->frame = frame;
  if (onoff == 0) {			/* the end of a dit or a dah */
    int o_dit = observation;		/* if it's a dit, then the length is the dit clock observation */
    int o_dah = observation / 3;	/* if it's a dah, then the length/3 is the dit clock observation */
    int d_dit = o_dit - dp->estimate;	/* the dit distance from the current estimate */
    int d_dah = o_dah - dp->estimate;	/* the dah distance from the current estimate */
    if (d_dit == 0 || d_dah == 0) {
      /* one of the observations is spot on, so 1/(d*d) will be infinite and the estimate is unchanged */
    } else {
      /* the weight of an observation is the observed frequency of the element scaled by inverse of
       * distance from our current estimate normalized to one over the observations made.
       */
      float w_dit = 1.0 * dp->n_dit / (d_dit*d_dit); /* raw weight of dit observation */
      float w_dah = 1.0 * dp->n_dah / (d_dah*d_dah); /* raw weight of dah observation */
      float wt = w_dit + w_dah;			     /* weight normalization */
      int update = (o_dit * w_dit + o_dah * w_dah) / wt;
      dp->estimate += update;
      dp->estimate /= 2;
    }
    int guess = 100 * observation / dp->estimate;    /* make a guess */
    if (guess < 200) {
      dp->n_dit += 1; return '.';
    } else {
      dp->n_dah += 1; return '-';
    }
  } else { /* the end of an inter-element, inter-letter, or a longer space */
    int o_ies = observation;
    int o_ils = observation / 3;
    int d_ies = o_ies - dp->estimate;
    int d_ils = o_ils - dp->estimate;
    int guess = 100 * observation / dp->estimate;
    if (d_ies == 0 || d_ils == 0) {
      /* if one of the observations is spot on, then 1/(d*d) will be infinite and the estimate is unchanged */	    
    } else if (guess > 500) {
      /* if it looks like a word space, it could be any length, don't worry about how long it is */
    } else {
      float w_ies = 1.0 * dp->n_ies / (d_ies*d_ies);
      float w_ils = 1.0 * dp->n_ils / (d_ils*d_ils);
      float wt = w_ies + w_ils;
      int update = (o_ies * w_ies + o_ils * w_ils) / wt;
      dp->estimate += update;
      dp->estimate /= 2;
      guess = 100 * observation / dp->estimate;
    }
    if (guess < 200) {
      dp->n_ies += 1; return 0;
    } else if (guess < 500) {
      dp->n_ils += 1; return ' ';
    } else {
      dp->n_iws += 1; return '\n';
    }
  }
}
#endif
