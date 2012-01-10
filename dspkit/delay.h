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
#ifndef DELAY_H
#define DELAY_H

#include "ring_buffer.h"

typedef struct {
  ring_buffer_t ring;
  int max_delay;
  int delay;
  float *buff;
} delay_t;

static void delay_init(delay_t *p, int samples) {
}

static void delay_set_delay(delay_t *p, int samples) {
  if (p->max_delay < samples) {
    // reallocate buff to fit, adjust max_delay
  }
  if (p->max_delay >= samples) {
    p->delay = samples;
    p->ring.rptr = ring_buffer_index(&p->ring, p->ring.wptr-p->delay);
  }
}

static float delay(delay_t *p, float sample) {
}

#endif
