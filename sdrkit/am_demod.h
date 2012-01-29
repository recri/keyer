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

#ifndef AM_DEMOD_H
#define AM_DEMOD_H

/*
** AM demodulation - rewritten from dttsp
   Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include "dmath.h"

typedef struct {
  float val;
  float dc;
  float smooth;
} am_demod_t;

typedef struct {
} am_demod_options_t;

static void *am_demod_init(am_demod_t *p) {
  p->val = 0.0f;
  p->dc = 0.0f;
  p->smooth = 0.0f;
  return p;
}

static float am_demod_process(am_demod_t *p, const float _Complex in) {
  p->val = cabsf(in);
  p->dc = 0.9999f * p->dc + 0.0001f * p->val;
  p->smooth = 0.5f * p->smooth + 0.5f * (p->val - p->dc);
  return p->smooth;
}

#endif
