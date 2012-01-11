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

/*
** Synchronous AM demodulation - rewritten from dttsp
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#ifndef SAM_DEMOD_H
#define SAM_DEMOD_H

#include <complex.h>
#include <math.h>

#include "pll.h"

typedef struct {
  pll_t pll;
  float lock;
  float dc;
} sam_demod_t;

static void *sam_demod_init(const sam_demod_t *p, const int sample_rate) {
  const float f_initial = 0.0f;
  const float f_lobound = -2000.0f;
  const float f_hibound =  2000.0f;
  const float f_bandwid =   300.0f;
  void *ep = pll_init(&p->pll, sample_rate, f_initial, f_lobound, f_hibound, f_bandwid);
  if (ep != &p->pll) return ep;

  p->lock = 0.5;
  p->dc = 0.0;

  return p;
}

static float _Complex sam_demod(sam_demod_t *p, float _Complex sig) {
  pll(&p->pll, sig, cabs(sig));

  p->lock = 0.999f * p->lock + 0.001f * fabsf(cimag(p->pll.delay));
  p->dc = 0.9999f * p->dc + 0.0001f * creal(p->pll.delay);
  float demout =  creal(p->pll.delay) - p->dc;

  return demout + I * demout;
}
#endif
