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

#ifndef IQ_NOISE_H
#define IQ_NOISE_H

/*
** The goal here is to simulate noise that originated at the antenna connection
** and went through the QSD, so the Q signal is 90 degrees from the I signal.
** And do it without calling any transcendental functions.
**
** This might be excessively perfect IQ noise, probably want to simulate a
** QSD with plain noise as input.
*/

#include "random_uniform.h"
#include "dmath.h"

typedef random_uniform_options_t iq_noise_options_t;

typedef random_uniform_t iq_noise_t;

static void *iq_noise_init(void *p) {
  return random_uniform_init(p);
}

static void iq_noise_configure(iq_noise_t *p, iq_noise_options_t *q) {
  random_uniform_configure((random_uniform_t *)p, (random_uniform_options_t *)q);
}

static float _Complex iq_noise_process(iq_noise_t *p) {
  float phase = two_pi * random_uniform_float(p);
  return cosf(phase) + I * sinf(phase);
}
#endif
