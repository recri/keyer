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
#ifndef FILTER_GOERTZEL_H
#define FILTER_GOERTZEL_H

#include "dspmath.h"

/*
** The Goertzel filter detects the power of a specified frequency
** very efficiently.
**
** This is based on http://en.wikipedia.org/wiki/Goertzel_algorithm
** and the video presentation of CW mode for the NUE-PSK modem
** at TAPR DCC 2011 by George Heron N2APB and Dave Collins AD7JT.
*/
typedef struct {
  float hertz;			// frequency to track
  float bandwidth;		// bandwidth of sampling
  int sample_rate;		// sample rate of input stream
} filter_goertzel_options_t;

typedef struct {
  float coeff;
  float s[4];
  int block_size;
  int i;
  float power;
  float energy;
} filter_goertzel_t;

static void filter_goertzel_configure(filter_goertzel_t *p, filter_goertzel_options_t *q) {
  p->coeff = 2.0f * cosf(two_pi * q->hertz / q->sample_rate);
  p->block_size = (int) (q->sample_rate / (int)q->bandwidth);
  p->i = p->block_size;
  p->s[0] = p->s[1] = p->s[2] = p->s[3] = 0.0f;
  p->energy = 0.0f;
}

static void *filter_goertzel_preconfigure(filter_goertzel_t *p, filter_goertzel_options_t *q) {
  if (q->bandwidth <= 0) return (void *)"bandwidth must be positive";
  if (q->hertz <= 0) return (void *)"frequency must be positive";
  if (q->sample_rate <= 0) return (void *)"sample rate must be postive";
  if (q->bandwidth > q->sample_rate / 4) return (void *)"bandwidth must be less than one-quarter of sample rate";
  if (q->hertz > q->sample_rate / 4) return (void *)"frequency must be less than one-quarter of sample rate";
  return p;
}

static void *filter_goertzel_init(filter_goertzel_t *p, filter_goertzel_options_t *q) {
  void *e = filter_goertzel_preconfigure(p, q); if (e != p) return e;
  filter_goertzel_configure(p, q);
  return p;
}

static int filter_goertzel_process(filter_goertzel_t *p, const float x) {
  p->s[(p->i)&3] = x + p->coeff * p->s[(p->i+1)&3] - p->s[(p->i+2)&3];
  p->energy += x*x;
  if (--p->i < 0) {
    p->power = (p->s[1]*p->s[1] + p->s[0]*p->s[0] - p->coeff*p->s[0]*p->s[1]) / (p->block_size/2);
    p->i = p->block_size;
    p->s[0] = p->s[1] = p->s[2] = p->s[3] = 0.0f;
    return 1;
  } else {
    return 0;
  }
}

#endif
