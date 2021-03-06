/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
#ifndef FILTER_MOVING_AVERAGE16_H
#define FILTER_MOVING_AVERAGE16_H

#include "dspmath.h"

// The following is cribbed from the source for fldigi-4.1.09

//=====================================================================
// Moving average filter
//
// Simple in concept, sublime in implementation ... the fastest filter
// in the west.  Also optimal for the processing of time domain signals
// characterized by a transition edge.  The is the perfect signal filter
// for CW, RTTY and other signals of that type.  For a given filter size
// it provides the greatest s/n improvement while retaining the sharpest
// leading edge on the filtered signal.
//=====================================================================

#define FILTER_MOVING_AVERAGE16_LEN 16

typedef struct {
  unsigned sum;
  unsigned i;
  unsigned in[FILTER_MOVING_AVERAGE16_LEN];
} filter_moving_average16_t;

static unsigned filter_moving_average16_init(filter_moving_average16_t *dp, unsigned init) {
  dp->sum = FILTER_MOVING_AVERAGE16_LEN * init;
  dp->i = 0;
  for (int i = 0; i < FILTER_MOVING_AVERAGE16_LEN; i++) dp->in[i] = init;
  return init;
}

static unsigned filter_moving_average16_process(filter_moving_average16_t *dp, unsigned a) {
  dp->sum -= dp->in[dp->i] - a;
  dp->in[dp->i] = a;
  dp->i += 1;
  dp->i &= (FILTER_MOVING_AVERAGE16_LEN-1);
  return dp->sum / FILTER_MOVING_AVERAGE16_LEN;
}

#endif // FILTER_MOVING_AVERAGE16_H
