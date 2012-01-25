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

#ifndef IQ_BALANCE_H
#define IQ_BALANCE_H

/*
** I/Q channel balance - rewritten from dttsp-cgran-r624
   Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include "dmath.h"

typedef struct {
  float sine_phase;			/* sine of phase correction */
  float linear_gain;			/* linear gain correction to I */
} iq_balance_options_t;

typedef struct {
  float sine_phase;
  float linear_gain;
} iq_balance_t;

static void iq_balance_configure(iq_balance_t *p, iq_balance_options_t *q) {
  p->sine_phase = q->sine_phase;
  p->linear_gain = q->linear_gain;
}

static void *iq_balance_preconfigure(iq_balance_t *p, iq_balance_options_t *q) {
  if (q->sine_phase < -1.0f || q->sine_phase > 1.0f) return (void *)"sine phase must be between -1 and +1";
  if (q->linear_gain <= 0.0f) return (void *)"linear gain must be positive";
  return p;
}

static void *iq_balance_init(iq_balance_t *p, iq_balance_options_t *q) {
  void *e = iq_balance_preconfigure(p, q); if (e != p) return e;
  iq_balance_configure(p, q);
  return p;
}

/*
** This has been reduced from the dttsp-cgran-r624 version to simply apply
** the indicated gain and phase corrections.
** See iq_correct* for an adaptive balancer.
*/
static float _Complex iq_balance_process(iq_balance_t *p, const float _Complex x) {
  return p->linear_gain * crealf(x) + (cimagf(x) + p->sine_phase * crealf(x)) * I;
}
#endif
