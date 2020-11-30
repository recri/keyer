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

#ifndef FILTER_COMPLEX_BANDPASS_H
#define FILTER_COMPLEX_BANDPASS_H

/*
** apply a complex FIR bandpass filter to a sample stream.
*/

#include "dspmath.h"
#include "filter_FIR.h"

#define FILTER_COMPLEX_BANDPASS_MAX_LENGTH (8*1024)

typedef struct {
  int length;			/* length of filter */
  int index;			/* index into circular buffer */
  float complex ring[FILTER_COMPLEX_BANDPASS_MAX_LENGTH];	/* limited size circular buffer */
  float complex coeff[FILTER_COMPLEX_BANDPASS_MAX_LENGTH];	/* filter coefficients */
} filter_complex_bandpass_t;

typedef struct {
  int length;
  int sample_rate;
  float high_frequency;		/* high cutoff of bandpass */
  float low_frequency;		/* low cutoff of bandpass */
  // derived options
  float complex coeff[FILTER_COMPLEX_BANDPASS_MAX_LENGTH];	/* new value for coeff */
} filter_complex_bandpass_options_t;

/* configure installs a new transformed filter kernel */
static void filter_complex_bandpass_configure(filter_complex_bandpass_t *p, filter_complex_bandpass_options_t *q) {
  p->length = q->length;
  complex_vector_copy(p->coeff, q->coeff, q->length);
}

static void *filter_complex_bandpass_preconfigure(filter_complex_bandpass_t *p, filter_complex_bandpass_options_t *q) {
  if (q->length > FILTER_COMPLEX_BANDPASS_MAX_LENGTH) return (void *)"filter length is too large";
  if (fabsf(q->low_frequency) >= q->sample_rate / 2) return (void *)"low frequency is too high for sample rate";
  if (fabsf(q->high_frequency) >= q->sample_rate / 2) return (void *)"high frequency is too high for sample rate";
  if ((q->low_frequency + 10) >= q->high_frequency) return (void *)"bandwidth is too narrow";
  if ((q->length&1) == 0) return (void *)"filter length must be odd";
  void *e = bandpass_complex(q->low_frequency, q->high_frequency, q->sample_rate, q->length, WINDOW_BLACKMAN_HARRIS, q->coeff); if (e != q->coeff)
    return e;
 return p;
}

static void *filter_complex_bandpass_init(filter_complex_bandpass_t *p, filter_complex_bandpass_options_t *q) {
  memset(p, 0, sizeof(filter_complex_bandpass_t));
  if (q->length < 3) return (void *)"filter length is too small";
  if ((q->length & 1) == 0) return (void *)"filter length must be odd";
  p->length = q->length;
  p->index = 0;
  void *e = filter_complex_bandpass_preconfigure(p, q); if (e != p) return e;
  filter_complex_bandpass_configure(p, q);
  return p;
}

static float complex filter_complex_bandpass_process(filter_complex_bandpass_t *p, float complex x) {
  p->index -= 1;
  p->index &= FILTER_COMPLEX_BANDPASS_MAX_LENGTH-1;
  p->ring[p->index] = x;
  float complex y = 0.0f;
  for (int i = 0; i < p->length; i += 1)
    y += p->coeff[i] * p->ring[(p->index+i)&(FILTER_COMPLEX_BANDPASS_MAX_LENGTH-1)];
  return y;
}
#endif
