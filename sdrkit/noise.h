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

#ifndef NOISE_H
#define NOISE_H

// if this isn't the first thing included, then all bets are off
// feature macros are extremely weird, since anyone can include the
// same file with the defines off
#define _SVID_SOURCE 
#define _BSD_SOURCE
#include <stdlib.h>

#include "dmath.h"

#ifndef RANDOM_STATE_SIZE
#define RANDOM_STATE_SIZE 32
#endif

#if RANDOM_STATE_SIZE < 8
#error "random_r state buffer size must be 8 or greater"
#endif

typedef struct {
  struct random_data data;
  char state[RANDOM_STATE_SIZE];
} noise_t;

static void *noise_init(void *p) {
  noise_t *noise = (noise_t *)p;
  if (initstate_r(12345678, noise->state, sizeof(noise->state), &noise->data) != 0) return "initstate_r failed";
  return p;
}

static void noise_configure(noise_t *p, unsigned int seed) {
  srandom_r(seed, &p->data);
}

static float _Complex noise_process(noise_t *p) {
  int32_t i, q;
  random_r(&p->data, &i);
  random_r(&p->data, &q);
  return (2.0f - 4.0f * (i / (float)RAND_MAX)) + I * (2.0f - 4.0f * (q / (float)RAND_MAX));
}
#endif
