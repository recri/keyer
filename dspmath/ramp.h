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

#include "dspmath.h"
#include "window.h"

/*
** Blackman Harris attack/decay ramp
** uses 1/2 of the Blackman Harris window function
** from sin(0 .. 0.5) for ramp on
** from sin(0.5 .. 1.0) for ramp off
*/
typedef struct {
  int do_rise;			/* rising or falling ramp */
  int target;			/* sample length of ramp */
  int current;			/* current sample point in ramp */
  float *ramp;			/* ramp values */
} ramp_t;

static void ramp_update(ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000.0f);
  if (r->target < 1) r->target = 1;
  if ((r->target & 1) == 0) r->target += 1;
  r->current = 0;
  r->ramp = realloc(r->ramp, r->target*sizeof(float));
  for (int i = 0; i < r->target; i += 1)
    r->ramp[i] = window_get(WINDOW_BLACKMAN_HARRIS, 2*r->target-1, i);
}

static void ramp_init(ramp_t *r, float ms, int samples_per_second) {
  r->ramp = NULL;
  ramp_update(r, ms, samples_per_second);
}

static void ramp_start_rise(ramp_t *r) {
  r->do_rise = 1;
  r->current = 0;
}

static void ramp_start_fall(ramp_t *r) {
  r->do_rise = 0;
  r->current = 0;
}

static float ramp_next(ramp_t *r) {
  r->current += 1;
  float v = r->current < r->target ? r->ramp[r->current] : 1;
  return r->do_rise ? v : 1-v;
}

static int ramp_done(ramp_t *r) {
  return r->current >= r->target;
}

static void ramp_free(ramp_t *r) {
  if (r->ramp != NULL) free(r->ramp);
}

#endif
