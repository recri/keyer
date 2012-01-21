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
#ifndef FM_DEMOD_H
#define FM_DEMOD_H

/*
** FM demodulation - rewritten from dttsp
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include <complex.h>
#include <math.h>

#include "pll.h"

typedef struct {
  pll_t pll;
  float afc, cvt;
} fm_demod_t;

void *fm_demod_init(fm_demod_t *p, const int sample_rate) {
  const float f_initial = 0.0f;
  const float f_lobound = -6000.0f;
  const float f_hibound =  6000.0f;
  const float f_bandwid =  5000.0f;
  void *ep = pll_init(&p->pll, sample_rate, f_initial, f_lobound, f_hibound, f_bandwid);
  if (ep != &p->pll) return ep;
  p->afc = 0.0;
  p->cvt = 0.45f * sample_rate / (M_PI * f_bandwid);
  return p;
}  

float _Complex fm_demod_process(fm_demod_t *p, const float _Complex sig) {
  pll(&p->pll, sig, 1.0f);
  p->afc = 0.9999f * p->afc + 0.0001f * p->pll.freq.f;
  float demout = (p->pll.freq.f - p->afc) * p->cvt;
  return demout + I * demout;
}

#endif
