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

#include "dspmath.h"

#if ! defined(OSCILLATOR_F) && ! defined(OSCILLATOR_T) && ! defined(OSCILLATOR_Z)
#error "oscillator.h has no implementation selected"
#endif

#ifdef OSCILLATOR_D
typedef double ofloat;
typedef double complex ocomplex;
#define osqrt(x) sqrt(x)
#define osquare(x) square(x)
#define otan(x) tan(x)
#define ocos(x) cos(x)
#define osin(x) sin(x)
#define opi	dpi
#define otwo_pi dtwo_pi
static const double oone = 1.0;
#else
typedef float ofloat;
typedef float complex ocomplex;
#define osqrt(x) sqrtf(x)
#define osquare(x) squaref(x)
#define otan(x) tanf(x)
#define ocos(x) cosf(x)
#define osin(x) sinf(x)
#define opi	pi
#define otwo_pi two_pi
static const float oone = 1.0f;
#endif

#ifdef OSCILLATOR_F
/*
** oscillator - a recursive filter
** in its original form it only generates
** positive frequencies. 
*/
typedef struct {
  ofloat xi, c, x, y;
  ocomplex (*finish)(ofloat x, ofloat y);
} oscillator_t;

static ocomplex oscillator_finish_positive_frequency(ofloat x, ofloat y) {
  return x + I*y;
}
static ocomplex oscillator_finish_negative_frequency(ofloat x, ofloat y) {
  return x - I*y;
}
static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  ofloat current_xi = o->xi;
  ofloat wps = hertz / samples_per_second;
  ofloat rps = wps * otwo_pi;
  o->c = osqrt(oone / (oone + osquare(otan(rps))));
  o->xi = osqrt((oone - o->c) / (oone + o->c));
  o->x *=  o->xi / current_xi;
  o->finish = (hertz > 0) ? oscillator_finish_positive_frequency : oscillator_finish_negative_frequency;
}

static void oscillator_reverse_phase(oscillator_t *o) {
  o->x = -o->x;
  o->y = -o->y;
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->x = ocos(radians) * o->xi;
  o->y = osin(radians);
}

static void oscillator_set_zero_phase(oscillator_t *o) {
  o->x = 1 * o->xi;
  o->y = 0;
}

static float complex oscillator_process(oscillator_t *o) {
  ofloat t = (o->x + o->y) * o->c;
  ofloat nx = t-o->y;
  ofloat ny = t+o->x;
  ofloat x = (o->x = nx) / o->xi; /* better as multiply by inverse? */
  ofloat y = o->y = ny;
  return o->finish(x, y);
}

#endif

#ifdef OSCILLATOR_T
/*
** oscillator - a trigonometric function
*/
typedef struct {
  ofloat phase, dphase;
} oscillator_t;

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  o->dphase = otwo_pi * hertz / samples_per_second;
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->phase = radians;
}

static void oscillator_set_zero_phase(oscillator_t *o) {
  o->phase = 0;
}

static void oscillator_reverse_phase(oscillator_t *o) {
  o->phase += opi;
}

static float complex oscillator_process(oscillator_t *o) {
  o->phase += o->dphase;
  while (o->phase > otwo_pi) o->phase -= otwo_pi;
  while (o->phase < -otwo_pi) o->phase += otwo_pi;
  return ocos(o->phase) + I * osin(o->phase);
}
#endif

#ifdef OSCILLATOR_Z
/*
** oscillator - a complex rotor
*/
typedef struct {
  ocomplex phase, dphase;
} oscillator_t;

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second) {
  ofloat dradians = otwo_pi * hertz / samples_per_second;
  o->dphase = ocos(dradians) + I * osin(dradians);
}

static void oscillator_reverse_phase(oscillator_t *o) {
  o->phase = -o->phase;
}

static void oscillator_set_phase(oscillator_t *o, float radians) {
  o->phase = ocos(radians) + I * osin(radians);
}

static void oscillator_set_zero_phase(oscillator_t *o) {
  o->phase = 1;
}

static float complex oscillator_process(oscillator_t *o) {
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
