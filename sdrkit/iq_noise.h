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

#ifndef IQ_NOISE_H
#define IQ_NOISE_H

/*
** The goal here is to simulate noise that originated at the antenna connection
** and went through the QSD, so the Q signal is 90 degrees from the I signal.
** And do it without calling any transcendental functions.
*/

// if this isn't the first thing included, then all bets are off
// feature macros are extremely weird, since anyone can include the
// same file with the defines off
#define _SVID_SOURCE 
#define _BSD_SOURCE
#include <stdlib.h>

#include "dmath.h"

#ifndef IQ_NOISE_RANDOM_STATE_SIZE
#define IQ_NOISE_RANDOM_STATE_SIZE 32
#endif

#if IQ_NOISE_RANDOM_STATE_SIZE < 8
#error "random_r state buffer size must be 8 or greater"
#endif

typedef struct {
  struct random_data data;
  char state[IQ_NOISE_RANDOM_STATE_SIZE];
} iq_noise_t;

static void *iq_noise_init(void *p) {
  iq_noise_t *iq_noise = (iq_noise_t *)p;
  if (initstate_r(12345678, iq_noise->state, sizeof(iq_noise->state), &iq_noise->data) != 0) return "initstate_r failed";
  return p;
}

static void iq_noise_configure(iq_noise_t *p, unsigned int seed) {
  srandom_r(seed, &p->data);
}

static float _Complex iq_noise_process(iq_noise_t *p) {
  int32_t d;
  random_r(&p->data, &d);
  float phase = (two_pi * d) / RAND_MAX;
  return cosf(phase) + I * sinf(phase);
}
#endif
