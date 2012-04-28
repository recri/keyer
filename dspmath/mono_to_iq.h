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
#ifndef MONO_TO_IQ_H
#define MONO_TO_IQ_H

/*
** If you have a mono audio channel at sample_rate and you ran it through
** a quadrature detector running at sample_rate/4, then the first
** sample would go to I, the second sample to Q, the third sample to
** I, the fourth sample to Q, and so on.  If you interpolated your I
** and Q streams back to sample_rate, you'd get an approximation of
** your original mono stream.
**
** So why not just take the original mono stream and the stream
** delayed by one sample as your I/Q stream?
*/

#include "dspmath.h"

typedef struct {
  float delayed_sample;
} mono_to_iq_t;

static void *mono_to_iq_init(mono_to_iq_t *p) {
  p->delayed_sample = 0.0f;
  return p;
}

static float _Complex mono_to_iq(mono_to_iq_t *p, float mono) {
  float _Complex z = p->delayed_sample + mono * I;
  p->delayed_sample = mono;
  return z;
}
#endif
