/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
#ifndef MOVING_AVERAGE_H
#define MOVING_AVERAGE_H

#include "dspmath.h"

#ifndef N_MOVING_AVERAGE
#error "N_MOVING_AVERAGE must be defined, positive, and a power of two."
#endif
#if N_MOVING_AVERAGE <= 0
#error "N_MOVING_AVERAGE must be positive."
#endif
#if (N_MOVING_AVERAGE&(N_MOVING_AVERAGE-1)) != 0
#error "N_MOVING_AVERAGE must be a power of two."
#endif

typedef struct {
  float initial_value;
} moving_average_options_t;

typedef struct {
  unsigned i;
  float average;
  float window[N_MOVING_AVERAGE];
} moving_average_t;

static void moving_average_configure(moving_average_t *p, moving_average_options_t *q) {
  p->i = 0;
  p->average = q->initial_value;
  for (int i = 0; i < N_MOVING_AVERAGE; i += 1) p->window[i] = q->initial_value;
}

static void *moving_average_preconfigure(moving_average_t *p, moving_average_options_t *q) {
  return p;
}

static void *moving_average_init(moving_average_t *p, moving_average_options_t *q) {
  void *e = moving_average_preconfigure(p, q); if (e != p) return e;
  moving_average_configure(p, q);
  return p;
}

static int moving_average_process(moving_average_t *p, const float x) {
  p->average += (x - p->window[p->i]) / N_MOVING_AVERAGE;
  p->window[p->i] = x;
  p->i += 1;
  p->i &= (N_MOVING_AVERAGE-1);
}

#endif
