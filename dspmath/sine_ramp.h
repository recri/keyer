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
#ifndef SINE_RAMP_H
#define SINE_RAMP_H

#include "dspmath.h"
#include "oscillator.h"

/*
** sine attack/decay ramp
** uses 1/4 of an oscillator period to generate a sine
** from sin(0 .. pi/2) for ramp on
** from sin(pi/2 .. pi) for ramp off
*/
typedef struct {
  int target;			/* sample length of ramp */
  int current;			/* current sample point in ramp */
  oscillator_t ramp;		/* ramp oscillator */
} sine_ramp_t;

static void sine_ramp_init(sine_ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000.0f);
  if (r->target < 1) r->target = 1;
  r->current = 0;
  oscillator_init(&r->ramp, 1000.0f/(4.0f*ms), 0.0f, samples_per_second);
}

static void sine_ramp_update(sine_ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000.0f);
  if (r->target < 1) r->target = 1;
  oscillator_update(&r->ramp, 1000.0f/(4.0f*ms), samples_per_second);
}

static void sine_ramp_start_rise(sine_ramp_t *r) {
  r->current = 0;
  oscillator_set_phase(&r->ramp, 0.0f);
}

static void sine_ramp_start_fall(sine_ramp_t *r) {
  r->current = 0;
  oscillator_set_phase(&r->ramp, half_pi);
}

static float sine_ramp_next(sine_ramp_t *r) {
  r->current += 1;
  return cimag(oscillator_process(&r->ramp));
}

static int sine_ramp_done(sine_ramp_t *r) {
  return r->current >= r->target;
}

#endif
