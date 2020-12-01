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
#ifndef HILBERT_H
#define HILBERT_H

#include "dspmath.h"
#include "complex.h"

/*
** hilsim from dttsp cgran source.
** this isn't a hilbert transform, but it imitates one
** in a remarkably small number of instructions, and I
** have no idea how it's doing it.
*/

typedef struct {
  float x[4], y[6], d[6];
} hilbert_t;

typedef struct {
} hilbert_options_t;

/// cf "Musical Engineer's Handbook" by Bernie Hutchins

static void *hilbert_init(hilbert_t *h, hilbert_options_t *opt) {
  return h;
}

static float _Complex hilbert_process(hilbert_t *h, const float _Complex in) {
  float xin = (creal(in)+cimag(in))/2;
    
  h->x[0] = h->d[1] - xin;
  h->x[1] = h->d[0] - h->x[0] * 0.00196f;
  h->x[2] = h->d[3] - h->x[1];
  h->x[3] = h->d[1] + h->x[2] * 0.737f;
    
  h->d[1] = h->x[1];
  h->d[3] = h->x[3];
    
  h->y[0] = h->d[2] - xin;
  h->y[1] = h->d[0] + h->y[0] * 0.924f;
  h->y[2] = h->d[4] - h->y[1];
  h->y[3] = h->d[2] + h->y[2] * 0.439f;
  h->y[4] = h->d[5] - h->y[3];
  h->y[5] = h->d[4] - h->y[4] * 0.586f;
    
  h->d[2] = h->y[1];
  h->d[4] = h->y[3];
  h->d[5] = h->y[5];
    
  h->d[0] = xin;
    
  return h->x[3] + h->y[5] * I;
}

#endif
