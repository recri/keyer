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

#ifndef IQ_CORRECT_H
#define IQ_CORRECT_H

/*
** I/Q channel balance correction - rewritten from dttsp cgran-r624
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
**
** What's going on here is that we are training an adaptive filter, with coefficients wi and wq,
** to purify our I/Q stream of any gain or phase imperfections introduced by the hardware.  The
** filter updates its coefficients according to the magnitude of mu, a larger mu moves faster.
**
** What happens when I test is that I can make it work if I give it enough signal to work on,
** and that signal can be my IQ noise generator, but I have to push the levels up to push the
** adaptation to convergence.  So there's another parameter to be balanced.
*/

#include "dmath.h"

typedef struct {
  float mu;			/* update factor, a time constant */
} iq_correct_options_t;

typedef struct {
  float mu;
  float complex w;
} iq_correct_t;

static void iq_correct_configure(iq_correct_t *p, iq_correct_options_t *q) {
  p->mu = q->mu;
}

static void *iq_correct_preconfigure(iq_correct_t *p, iq_correct_options_t *q) {
  if (q->mu < 0) return (void *)"mu must be non-negative";
  return p;
}

static void *iq_correct_init(iq_correct_t *p, iq_correct_options_t *q) {
  p->w = 0.0f;
  void *e = iq_correct_preconfigure(p, q); if (e != p) return e;
  iq_correct_configure(p, q);
  return p;
}

static float complex iq_correct_process(iq_correct_t *p, const float complex z0) {
#if 1
  float complex z1 = z0 + p->w * conjf(z0);
  p->w -= p->mu * z1 * z1;
  return z1;
#endif
#if 0
  // this is the gnuradio routine
  // now I'm confused which one works
  float zi = crealf(z0) - crealf(p->w) * cimagf(z0);
  float zq = cimagf(z0) - cimagf(p->w) * crealf(z0);
  p->w += p->mu * (zq * crealf(z0) + I * zi * cimagf(z0));
  return zi + I * zq;
#endif
#if 0
  float complex z1 = z0 + (p->wi+I*p->wq) * conjf(z0);
  float complex dw = p->mu * z1 * z1;
  p->wi -= crealf(dw);
  p->wq -= cimagf(dw);
#endif
}
#endif
