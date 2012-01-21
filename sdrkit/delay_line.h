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
#ifndef DELAY_LINE_H
#define DELAY_LINE_H

#include "float_ring_buffer.h"

typedef struct {
  int max_delay;
  int delay;
  ring_buffer_t ring;
  float *buff;
} delay_line_t;
typedef struct {
  int delay;
  int max_delay;
  float *buff;
} delay_line_options_t;

static void *delay_line_init(delay_line_t *dlp, delay_line_options_t *q) {
  dlp->max_delay = q->max_delay;
  dlp->delay = q->delay;
  dlp->buff = q->buff;
  float_ring_buffer_options_t opt = { q->max_delay, q->buff };
  void *p = float_ring_buffer_init(&dlp->ring, &opt); if (p != &p->ring) return p;
  return dlp;
}

static void delay_line_configure(delay_line_t *dlp, delay_line_options_t *q) {
  int d = q->delay-dlp->delay;
  dlp->delay = q->delay;
  p->ring.rptr = float_ring_buffer_index(&p->ring, p->ring.rptr+d);
}

static void *delay_line_preconfigure(delay_line_t *dlp, delay_line_options_t *q) {
  if (q->delay > dlp->max_delay) {
    return "delay exceeds max_delay"
  }
  return dlp;
}
  
static float delay_line_process(delay_line_t *p, float sample) {
  float delayed_sample;
  float_ring_buffer_get(&p->ring, 1, &delayed_sample);
  float_ring_buffer_put(&p->ring, 1, &sample);
  return delayed_sample;
}

#endif
