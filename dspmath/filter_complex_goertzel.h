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
#ifndef FILTER_COMPLEX_GOERTZEL_H
#define FILTER_COMPLEX_GOERTZEL_H

#include "dspmath.h"

/*
** the following implementation comes from
** https://stackoverflow.com/questions/8835806/c-c-goertzel-algorithm-with-complex-output-or-magnitudephase
** contributed by https://stackoverflow.com/users/4867193/drm
**
** But it is still computing on a real sample stream.
*/

#if 0
/* goertzelfilter.h
*/

#ifndef GOERTZELFILTER_H_
#define GOERTZELFILTER_H_

#include <complex.h>

typedef struct goertzelfilterstruct {
  double coeff ;
  double sine ;
  double cosine ;
} GoertzelFilter;

GoertzelFilter goertzelSetup( double normalizedfreq );

double complex goertzelFilterC( double *sample, int nsamples, GoertzelFilter *g );

#endif

/* goertzelfilter.c
*/

#include <math.h>
#include <stdlib.h>
#include <complex.h>

#include "goertzelfilter.h"

GoertzelFilter goertzelSetup( double normalizedfreq )
{
  double w = 2*M_PI*normalizedfreq;
  double wr, wi;

  GoertzelFilter g;

  wr = cos(w);
  wi = sin(w);
  g.coeff = 2 * wr;
  g.cosine = wr;
  g.sine = wi;

  return g;
}

double complex goertzelFilterC( double *samples, int nsamples, GoertzelFilter *g )
{
  double sprev = 0.0;
  double sprev2 = 0.0;
  double s, imag, real;
  int n;

  for (n=0; n<nsamples; n++ ) {
    s = samples[n] + g->coeff * sprev - sprev2;
    sprev2 = sprev;
    sprev = s;
  }

  real = sprev*g->cosine - sprev2;
  imag = -sprev*g->sine;

  return real + I*imag;
}
#endif
/*
** The Goertzal filter generalized to a complex stream
*/
typedef struct {
  float hertz;			// frequency to track
  float bandwidth;		// bandwidth of sampling
  int sample_rate;		// sample rate of input stream
} filter_complex_goertzel_options_t;

typedef struct {
  float coeff;
  float cosine;
  float sine;
  float complex s[4];
  float sum2;
  int block_size;
  int i;
  float complex power;
  float energy;			// sum of squared samples
} filter_complex_goertzel_t;

static void filter_complex_goertzel_configure(filter_complex_goertzel_t *p, filter_complex_goertzel_options_t *q) {
  double w = two_pi * q->hertz / q->sample_rate;
  p->cosine = cosf(w);
  p->sine = sinf(w);
  p->coeff = 2.0f * p->cosine;
  p->block_size = (int) (0.5 + (q->sample_rate / q->bandwidth));
  p->i = p->block_size;
  p->s[0] = p->s[1] = p->s[2] = p->s[3] = 0.0f;
  p->sum2 = 0.0f;
}

static void *filter_complex_goertzel_preconfigure(filter_complex_goertzel_t *p, filter_complex_goertzel_options_t *q) {
  if (q->bandwidth <= 0) return (void *)"bandwidth must be positive";
  if (q->sample_rate <= 0) return (void *)"sample rate must be postive";
  // if (q->bandwidth > q->sample_rate / 2) return (void *)"bandwidth must be less than one-half of sample rate";
  // if (fabs(q->hertz) > q->sample_rate / 2) return (void *)"frequency must be less than one-half of sample rate";
  return p;
}

static void *filter_complex_goertzel_init(filter_complex_goertzel_t *p, filter_complex_goertzel_options_t *q) {
  void *e = filter_complex_goertzel_preconfigure(p, q); if (e != p) return e;
  filter_complex_goertzel_configure(p, q);
  return p;
}

static int filter_complex_goertzel_process(filter_complex_goertzel_t *p, const float complex x) {
  p->s[(p->i)&3] = x + p->coeff * p->s[(p->i+1)&3] - p->s[(p->i+2)&3];
  p->sum2 += x * conjf(x);
  if (--p->i < 0) {
    double real = p->cosine*p->s[0] - p->s[1];
    double imag = -p->sine*p->s[0];
    p->power = (real + I*imag) / (p->block_size/2);
    p->energy = p->sum2;
    p->i = p->block_size;
    p->s[0] = p->s[1] = p->s[2] = p->s[3] = 0.0f;
    p->sum2 = 0;
    return 1;
  } else {
    return 0;
  }
}

static void filter_complex_goertzel_block(filter_complex_goertzel_t *p, float complex *x, int n) {
  p->s[0] = p->s[1] = p->s[2] = p->s[3] = 0.0f;
  p->sum2 = 0.0f;
  for (int i = 0; i < n; i += 1) {
    p->s[(i+0)&3] = x[i] + p->coeff * p->s[(i+1)&3] - p->s[(i+2)&3];
    p->sum2 += x[i] * conjf(x[i]);
    double real = p->cosine*p->s[(i+0)&3] - p->s[(i+1)&3];
    double imag = -p->sine*p->s[(i+0)&3];
    x[i] = (real + I*imag) / ((i+1.0f)/2);
  }
  p->power = x[n-1];
  p->energy = p->sum2;
}

#endif
