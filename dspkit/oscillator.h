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

/*
** oscillator.
** uses a recursive filter which will oscillate up to 1/4 sample rate
*/
typedef struct {
  float xi, c, x, y;
} oscillator_t;

static float squaref(float x) { return x * x; }

static void oscillator_set_hertz(oscillator_t *o, float hertz, int samples_per_second, int init) {
  const float pi = 3.14159265358979323846;
  float current_xi = o->xi;
  float wps = hertz / samples_per_second;
  float rps = wps * 2 * pi;
  o->c = sqrtf(1.0 / (1.0 + squaref(tanf(rps))));
  o->xi = sqrtf((1.0 - o->c) / (1.0 + o->c));
  if (init) {
    o->x = o->xi;
    o->y = 0;
  } else {
    o->x *=  o->xi / current_xi;
  }
}

static void oscillator_init(oscillator_t *o, float hertz, int samples_per_second) {
  oscillator_set_hertz(o, hertz, samples_per_second, 1);
}

static void oscillator_update(oscillator_t *o, float hertz, int samples_per_second) {
  oscillator_set_hertz(o, hertz, samples_per_second, 0);
}

static void oscillator_reset(oscillator_t *o) {
  o->x = o->xi;
  o->y = 0;
}

/*
  check if keeping 1/xi is worth while, 
*/
static void oscillator_next_xy(oscillator_t *o, float *x, float *y) {
  float t = (o->x + o->y) * o->c;
  float nx = t-o->y;
  float ny = t+o->x;
  *x = (o->x = nx) / o->xi;
  *y = o->y = ny;
}

static float _Complex oscillator(oscillator_t *o) {
  float x, y;
  oscillator_next_xy(o,&x,&y);
  return x + I * y;
}
#endif
