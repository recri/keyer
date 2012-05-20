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

#ifndef MOD_AM_H
#define MOD_AM_H

/*
** AM modulation - rewritten from dttsp
   Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include "dspmath.h"

typedef struct {
  float carrier_level;
  float one_m_carrier_level;
} mod_am_t;

typedef struct {
  float carrier_level;
} mod_am_options_t;

static void mod_am_configure(mod_am_t *p, mod_am_options_t *q) {
  p->carrier_level = q->carrier_level;
  p->one_m_carrier_level = 1.0f - p->carrier_level;
}

static void *mod_am_preconfigure(mod_am_t *p, mod_am_options_t *q) {
  return p;
}

static void *mod_am_init(mod_am_t *p, mod_am_options_t *q) {
  void *e = mod_am_preconfigure(p,q); if (e != p) return e;
  mod_am_configure(p, q);
  return p;
}

static complex float mod_am_process(mod_am_t *p, const float in) {
  return p->carrier_level + p->one_m_carrier_level * in;
}

#endif
