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
#ifndef LO_MIXER_H
#define LO_MIXER_H

#include <complex.h>

#include "oscillator.h"
#include "mixer.h"

typedef struct {
  oscillator_t lo;
} lo_mixer_t;

static void lo_mixer_set_hertz(lo_mixer_t *p, float hertz, int samples_per_second, int init) {
  oscillator_set_hertz(&p->lo, hertz, samples_per_second, init);
}

static void lo_mixer_init(lo_mixer_t *p, float hertz, int samples_per_second) {
  oscillator_init(&p->lo, hertz, samples_per_second);
}

static void lo_mixer_update(lo_mixer_t *p, float hertz, int samples_per_second) {
  oscillator_update(&p->lo, hertz, samples_per_second);
}

static void lo_mixer_reset(lo_mixer_t *p) {
  oscillator_reset(&p->lo);
}

static float _Complex lo_mixer(lo_mixer_t *p, float _Complex a) {
  return mixer(a, oscillator(&p->lo));
}
#endif
