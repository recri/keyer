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
**
** As Rob Frohne pointed out, adapting the mu to the size of the input signal is probably
** important.  Hand picked mu's tend to blow up the filter when a strong signal comes into the
** pass band.
**
** My idea is that one can sense the filter progress by looking at the average updates to w
** and the cumulative change in w.  If the average updates add up to the cumulative change
** then the filter is adapting, a larger mu might make adaptation faster.
**
** But mu needs to be interpreted as a scaling factor on the input signal magnitude, not an
** absolute magnitude.
*/

#include "dmath.h"

#ifndef IQ_CORRECT_MAX_MAG_DW
#define IQ_CORRECT_MAX_MAG_DW 0.001
#endif

typedef struct {
  float mu;			/* update factor, a loop gain */
} iq_correct_options_t;

typedef struct {
  float mu;
  float complex w;
  // instrumentation for automatic tuning
  float complex w0;		/* w at beginning of buffer */
  float complex sum_abs_dw;	/* sum absolute updates to w over buffer */
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

static void iq_correct_preprocess(iq_correct_t *p) {
  p->w0 = p->w;
  p->sum_abs_dw = 0.0f;
}

static void iq_correct_postprocess(iq_correct_t *p, int nsamples) {
  // ensure that the filter is healthy
  if ( ! isfinite(crealf(p->w)) ||
       ! isfinite(cimagf(p->w)) ||
       fabsf(crealf(p->w)) >= 1 ||
       fabsf(cimagf(p->w)) >= 1) {
    // the filter blew up on us, reset
    p->w = 0.0f;
    p->mu = 0.0625f;
  } else {
    // the filter is finite
    // compute the average update per sample
    const float mag_dw = cabsf(p->w - p->w0) / nsamples;
    if (mag_dw > IQ_CORRECT_MAX_MAG_DW) {
      // the updates are greater than the allowed max
      // reduce mu to reduce the size of the updates
      p->mu /= mag_dw / IQ_CORRECT_MAX_MAG_DW;
    } else {
      // the updates per sample are below the upper limit
      // compute the update per sample if all updates were
      // in the same direction
      const float mag_abs_dw = cabsf(p->sum_abs_dw) / nsamples;
      
    }
  }
}

static float complex iq_correct_process(iq_correct_t *p, const float complex z0) {
  const float complex dz = p->w * conjf(z0);
  const float complex z1 = z0 + dz;
  const float complex dw = -p->mu * z1 * z1;
  p->w += dw;

  // instrumentation
  p->sum_abs_dw += fabsf(crealf(dw)) + I * fabsf(cimagf(dw));	/* sum absolute updates */
  
  return z1;
#if 0
  // this is the gnuradio routine
  // now I'm confused which one works
  float zi = crealf(z0) - crealf(p->w) * cimagf(z0);
  float zq = cimagf(z0) - cimagf(p->w) * crealf(z0);
  p->w += p->mu * (zq * crealf(z0) + I * zi * cimagf(z0));
  return zi + I * zq;
#endif
#if 0
  // this is just a rewrite
  float complex z1 = z0 + (p->wi+I*p->wq) * conjf(z0);
  float complex dw = p->mu * z1 * z1;
  p->wi -= crealf(dw);
  p->wq -= cimagf(dw);
#endif
}

#endif
