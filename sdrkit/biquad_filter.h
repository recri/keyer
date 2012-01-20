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

#ifndef BIQUAD_FILTER_H
#define BIQUAD_FILTER_H

/*
** Biquad filter - rewritten from everywhere
*/

#include <complex.h>

typedef struct {
  float a1, a2, b0, b1, b2;
  float _Complex w11, w12;
} biquad_filter_t;

static void *biquad_filter_init(biquad_filter_t *p) {
  // p->a1 = p->a2 = p->b0 = p->b1 = p->b2 = 0.0f;
  p->w11 = p->w12 = 0.0f;
  return p;
}

static void biquad_filter_config(biquad_filter_t *p, float a1, float a2, float b0, float b1, float b2) {
  p->a1 = a1;
  p->a2 = a2;
  p->b0 = b0;
  p->b1 = b1;
  p->b2 = b2;
}

static float _Complex biquad_filter_process(biquad_filter_t *p, const float _Complex x) {
  float _Complex w10 = x - p->a1 * p->w11 + p->a2 * p->w12;
  float _Complex y = p->b0 * w10 + p->b1 * p->w11 + p->b2 * p->w12;
  p->w12 = p->w11;
  p->w11 = w10;
  return y;
}
#endif
