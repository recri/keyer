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
#ifndef RAMP_H
#define RAMP_H

#include "osc.h"

/*
** sine attack/decay ramp
** uses 1/4 of an oscillator period to generate a sine
*/
typedef struct {
  int target;			/* sample length of ramp */
  int current;			/* current sample point in ramp */
  osc_t ramp;			/* ramp oscillator */
} ramp_t;

static void ramp_init(ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000);
  r->current = 0;
  osc_init(&r->ramp, 1000/(4*ms), samples_per_second);
}

static void ramp_update(ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000);
  osc_update(&r->ramp, 1000/(4*ms), samples_per_second);
}

static void ramp_reset(ramp_t *r) {
  r->current = 0;
  osc_reset(&r->ramp);
}

static float ramp_next(ramp_t *r) {
  float x, y;
  r->current += 1;
  osc_next_xy(&r->ramp, &x, &y);
  return y;
}

static int ramp_done(ramp_t *r) {
  return r->current == r->target;
}

#endif
