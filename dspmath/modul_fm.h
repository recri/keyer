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

#ifndef MODUL_FM_H
#define MODUL_FM_H

/*
** FM modulation - rewritten from dttsp
   Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include "dspmath.h"

typedef struct {
  float phase;
  float cvtmod2freq;
} modul_fm_t;

typedef struct {
  float deviation;		/* 5000 Hz default */
  float sample_rate;
} modul_fm_options_t;

static void modul_fm_configure(modul_fm_t *p, modul_fm_options_t *q) {
  p->phase = 0.0f;
  p->cvtmod2freq = q->deviation * two_pi / q->sample_rate;
}

static void *modul_fm_preconfigure(modul_fm_t *p, modul_fm_options_t *q) {
  return p;
}

static void *modul_fm_init(modul_fm_t *p, modul_fm_options_t *q) {
  void *e = modul_fm_preconfigure(p,q); if (e != p) return e;
  modul_fm_configure(p, q);
  return p;
}

static complex float modul_fm_process(modul_fm_t *p, const float complex in) {
  p->phase += crealf(in) * p->cvtmod2freq;
  return cexpf(I * p->phase);
}

#endif
