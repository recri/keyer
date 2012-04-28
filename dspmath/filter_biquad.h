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

#ifndef FILTER_BIQUAD_H
#define FILTER_BIQUAD_H

/*
** Biquad filter - rewritten from everywhere
*/

#include "dspmath.h"

typedef struct {
  float a1, a2, b0, b1, b2;
  float _Complex w11, w12;
} filter_biquad_t;

typedef struct {
  float a1, a2, b0, b1, b2;
} filter_biquad_options_t;
  
static void *filter_biquad_init(filter_biquad_t *p) {
  // p->a1 = p->a2 = p->b0 = p->b1 = p->b2 = 0.0f;
  p->w11 = p->w12 = 0.0f;
  return p;
}

static void filter_biquad_config(filter_biquad_t *p, filter_biquad_options_t *q) {
  p->a1 = q->a1;
  p->a2 = q->a2;
  p->b0 = q->b0;
  p->b1 = q->b1;
  p->b2 = q->b2;
}

static void filter_biquad_preconfig(filter_biquad_t *p, filter_biquad_options_t *q) {
}

static float _Complex filter_biquad_process(filter_biquad_t *p, const float _Complex x) {
  float _Complex w10 = x - p->a1 * p->w11 + p->a2 * p->w12;
  float _Complex y = p->b0 * w10 + p->b1 * p->w11 + p->b2 * p->w12;
  p->w12 = p->w11;
  p->w11 = w10;
  return y;
}
#endif
