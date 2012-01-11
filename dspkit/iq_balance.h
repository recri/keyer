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
** I/Q channel balance - rewritten from dttsp
   Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include <complex.h>

#define _mu 0.25f	/* fudge? const: 0.25 */

typedef struct {
  float phase;			/* sin of phase correction */
  float gain;			/* linear gain correction to I */
  _Complex float w;		/* memory? init: 0.00+0.00 * I */
} iq_balance_t;

static void *iq_balance_init(iq_balance_t *p) {
  p->phase = 0.0f;
  p->gain = 1.0f;
  p->w = 0.0f;
  return p;
}

static float _Complex iq_balance(iq_balance_t *p, const float _Complex in) {
  float _Complex adj_in = creal(in) * p->gain + (cimag(in) + p->phase * creal(in)) * I;
  float _Complex y = adj_in + p->w * conj(adj_in);
  p->w = (1.0 - _mu * 0.000001f) * p->w - _mu * y * y;
  return y;
}
#endif
