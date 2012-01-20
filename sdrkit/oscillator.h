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
#ifndef OSCILLATOR_H
#define OSCILLATOR_H

#if ! defined(OSCILLATOR_F) && ! defined(OSCILLATOR_T) && ! defined(OSCILLATOR_Z)
#error "oscillator.h has no implementation selected"
#endif

#ifdef OSCILLATOR_F

#include "dmath.h"

/*
** oscillator.
** uses a recursive filter which will oscillate up to 1/4 sample rate
*/
typedef struct {
  float xi, c, x, y;
} oscillator_t;

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  const float pi = 3.14159265358979323846;
  float current_xi = o->xi;
  float wps = hertz / samples_per_second;
  float rps = wps * 2 * pi;
  o->c = sqrtf(1.0 / (1.0 + squaref(tanf(rps))));
  o->xi = sqrtf((1.0 - o->c) / (1.0 + o->c));
  o->x *=  o->xi / current_xi;
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->x = cosf(radians) * o->xi;
  o->y = sinf(radians);
}

static float _Complex oscillator_process(oscillator_t *o) {
  float t = (o->x + o->y) * o->c;
  float nx = t-o->y;
  float ny = t+o->x;
  float x = (o->x = nx) / o->xi; /* better as multiply by inverse? */
  float y = o->y = ny;
  return x + I * y;
}

#endif

#ifdef OSCILLATOR_T

#include "dmath.h"

/*
** oscillator.
** uses a trigonometric functions
*/
typedef struct {
  float phase, dphase;
} oscillator_t;

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  o->dphase = 2.0f * pi * hertz / samples_per_second;
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->phase = radians;
}

static float _Complex oscillator_process(oscillator_t *o) {
  o->phase += o->dphase;
  while (o->phase > two_pi) o->phase -= two_pi;
  while (o->phase < -two_pi) o->phase += two_pi;
  return cosf(o->phase) + I * sinf(o->phase);
}
#endif

#if OSCILLATOR_Z


#include "dmath.h"

/*
** oscillator.
** a recursive complex mixer
*/
typedef struct {
  float _Complex phase, dphase;
} oscillator_t;

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  float dradians = 2.0f * pi * hertz / samples_per_second;
  o->dphase = cosf(dradians) + I * sinf(dradians);
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->phase = cosf(radians) + I * sinf(radians);
}

static float _Complex oscillator_process(oscillator_t *o) {
  return o->phase *= o->dphase;
}

#endif

/*
** code common to all implementations.
*/

static void *oscillator_init(oscillator_t *o, float hertz, float radians, int samples_per_second) {
  oscillator_set_hertz(o, hertz, samples_per_second);
  oscillator_set_phase(o, radians);
  return o;
}

static void oscillator_update(oscillator_t *o, float hertz, int samples_per_second) {
  oscillator_set_hertz(o, hertz, samples_per_second);
}

static void oscillator_reset(oscillator_t *o) {
  oscillator_set_phase(o, 0.0f);
}

#endif
