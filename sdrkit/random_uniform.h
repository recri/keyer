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

#ifndef RANDOM_UNIFORM_H
#define RANDOM_UNIFORM_H

// if this isn't the first thing included, then random_r may end up undefined
// feature macros are extremely weird, since anyone can include the
// same file with the defines off
#define _SVID_SOURCE 
#define _BSD_SOURCE
#include <stdlib.h>

#include "dmath.h"

#ifndef RANDOM_UNIFORM_STATE_SIZE
#define RANDOM_UNIFORM_STATE_SIZE 32
#endif

#if RANDOM_UNIFORM_STATE_SIZE < 8
#error "random_r state buffer size must be 8 or greater"
#endif

typedef struct {
  unsigned int seed;
} random_uniform_options_t;

typedef struct {
  struct random_data data;
  char state[RANDOM_UNIFORM_STATE_SIZE];
} random_uniform_t;

static void *random_uniform_init(void *p) {
  random_uniform_t *random_uniform = (random_uniform_t *)p;
  if (initstate_r(12345678, random_uniform->state, sizeof(random_uniform->state), &random_uniform->data) != 0) return "initstate_r failed";
  return p;
}

static void random_uniform_configure(random_uniform_t *p, random_uniform_options_t *q) {
  srandom_r(q->seed, &p->data);
}

static int random_uniform_int(random_uniform_t *p) {
  int32_t i;
  random_r(&p->data, &i);
  return i;
}

static float random_uniform_float(random_uniform_t *p) {
  return (float)random_uniform_int(p) / (float)RAND_MAX;
}
#endif
