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

#ifndef AGC_H
#define AGC_H

//
// This is the dttsp agc rewritten.
//
// All the unused variables are omitted, almost everything has been renamed,
// and various constants are computed.
//
// We buffer 3*attack time samples and output a delayed sample scaled by
// the gain computed from the current sample and the sample 3*attack/4
// behind the current sample.
// We maintain a ring buffer of sample magnitudes to only do one square
// root per sample.
// We fold the constants that adjust the target level at configure time.
// We convert hang times into sample counts at configure time.
// The hang threshold level is specified directly as a level.
//

#include "dmath.h"
#include <fftw3.h>

// -agc long   = -attack 2 -decay 2000 -hangtime 750 -fasthangtime 100
// -agc slow   = -attack 2 -decay  500 -hangtime 500 -fasthangtime 100
// -agc medium = -attack 2 -decay  250 -hangtime 250 -fasthangtime 100
// -agc fast   = -attack 2 -decay  100 -hangtime 100 -fasthangtime 100
// rx default  = -attack 2 -decay  500 -hangtime 500 -fasthangtime  48 -limit 1.0 -slope 1 -maxlinear 31622.8 -minlinear 0.00001 -curlinear 1
// tx default  = -attack 2 -decay  500 -hangtime 500 -fasthangtime  48 -limit 1.1 -slope 1 -maxlinear    5.62 -minlinear 1.0     -curlinear 1.0

typedef struct {
  float target;				// target sample level
  float attack;				// attack time (ms)
  float decay;				// decay time (ms)
  float slope;				// slope
  float hang_time;			// hangtime (ms)
  float fast_hang_time;			// fast hangtime (ms)
  float sample_rate;			// samples/second
  float max_linear;			// maximum linear gain
  float min_linear;			// minimum linear gain
  float hang_linear;			// hang linear gain threshold 
  int new_size;				// new ring buffer size
  float complex *new_samples;		// new sample ring buffer
  float *new_magnitudes;		// new magnitude ring buffer
  int old_size;				// old ring buffer size
  float complex *old_samples;		// old sample ring buffer
  float *old_magnitudes;		// old magnitude ring buffer
} agc_options_t;

typedef struct {
  float raw_linear;			// raw linear gain for s-metering
  float target_level;			// target sample level
  float attack, one_m_attack;		// attack interpolation coefficients
  float decay, one_m_decay;		// decay interpolation coefficients
  int hang_samples;			// hang time in samples
  float now_linear;			// current linear gain
  int hang_count;			// samples remaining in hang

  float fast_target_level;		// fast target sample level
  float fast_attack, fast_one_m_attack;	// fast attack interpolation coefficients
  float fast_decay, fast_one_m_decay;	// fast decay interpolation coefficients
  int fast_hang_samples;		// fast hang time in samples
  float fast_now_linear;		// current fast linear gain
  int fast_hang_count;			// samples remaining in fast hang

  float slope;				// 
  float max_linear;			// maximum linear gain
  float min_linear;			// minimum linear gain
  float hang_linear;			// hang linear gain threshold
  float complex *samples;		// delay line of samples
  float *magnitudes;			// delay line of sample magnitudes
  unsigned mask;			// index mask
  unsigned in;				// input index
  unsigned out;				// output index
  unsigned fast;			// fast index
} agc_t;

static void agc_configure(agc_t *p, agc_options_t *q) {
  p->target_level = q->target / 1.1f;
  p->fast_target_level = q->target / 1.2f;

  p->one_m_attack = expf(-1000.0f / (q->attack*q->sample_rate));
  p->attack = 1.0f - p->one_m_attack;
  p->one_m_decay = expf(-1000.0f / (q->decay*q->sample_rate));
  p->decay = 1.0f - p->one_m_decay;
  
  p->fast_one_m_attack = expf(-1000.0f / (0.2f*q->sample_rate));
  p->fast_attack = 1.0f - p->fast_one_m_attack;
  p->fast_one_m_decay = expf(-1000.0f / (3.0f*q->sample_rate));
  p->fast_decay = 1.0f - p->fast_one_m_decay;

  p->hang_samples = q->hang_time * q->sample_rate / 1000.0f;
  p->hang_count = -1;
  p->fast_hang_samples = q->fast_hang_time * q->sample_rate / 1000.0f;
  p->fast_hang_count = -1;

  p->now_linear = 1.0f;
  p->fast_now_linear = 1.0f;

  p->slope = q->slope;
  p->max_linear = q->max_linear;
  p->min_linear = q->min_linear;
  p->hang_linear = q->hang_linear;
  q->old_size = p->mask+1;
  q->old_samples = p->samples;
  q->old_magnitudes = p->magnitudes;
  p->mask = q->new_size-1;
  p->samples = q->new_samples;
  p->magnitudes = q->new_magnitudes;
  p->in = 0;
  p->out = (int)((3 * q->attack * q->sample_rate) / 1000.0f);
  p->fast = p->out / 4;		// 72 is the hardwired constant in dttsp
}

static void *agc_preconfigure(agc_t *p, agc_options_t *q) {
  if (q->old_samples) {
    fftwf_free(q->old_samples); q->old_samples = NULL;
  }
  if (q->old_magnitudes) {
    fftwf_free(q->old_magnitudes); q->old_magnitudes = NULL;
  }
  q->new_size = nblock2((int)((3 * q->attack * q->sample_rate) / 1000.0f));
  q->new_samples = fftwf_malloc(q->new_size * sizeof(float complex));
  if (q->new_samples == NULL)
    return (void *)"memory allocation failure #1";
  q->new_magnitudes = fftwf_malloc(q->new_size * sizeof(float));
  if (q->new_magnitudes == NULL) {
    fftwf_free(q->new_samples); q->new_samples = NULL;
    return (void *)"memory allocation failure #2";
  }
  return p;
}

static void *agc_init(agc_t *p, agc_options_t *q) {
  void *e = agc_preconfigure(p, q); if (e != p) return e;
  agc_configure(p, q);
  return p;
}

static float _Complex agc_process(agc_t *p, float _Complex z) {
  // store input sample
  p->samples[p->in] = z;

  // compute magnitude of input sample and store
  float mag = cabsf(z);
  p->magnitudes[p->in] = mag;

  // compute raw slow gain
  float lin = mag ? p->target_level / mag : p->now_linear;

  if (lin < p->hang_linear) {
    // if the linear gain is less than the threshold, then expire the hang time window
    p->hang_count = -1;
  }

  if (lin >= p->now_linear) {
    // the linear gain is greater than the current gain
    // compute the raw decayed linear gain
    p->raw_linear = p->one_m_decay * p->now_linear + p->decay * lin;
    if (--p->hang_count < 0) {
      // hang time window expired, compute decayed linear gain
      p->now_linear = p->one_m_decay * p->now_linear + p->decay * minf(p->max_linear, lin);
      // clamp to the min and max linear gain
      p->now_linear = minf(maxf(p->now_linear, p->min_linear), p->max_linear);
    }
  } else {
    // if the linear gain is less than the current gain
    // compute the raw attacked linear gain
    p->raw_linear = p->one_m_attack * p->now_linear + p->attack * lin;
    // restart the hang time window
    p->hang_count = p->hang_samples;
    // compute the attacked linear gain
    p->now_linear = p->one_m_attack * p->now_linear + p->attack * maxf(p->min_linear, lin);
    // clamp to the min and max linear gain
    p->now_linear = minf(maxf(p->now_linear, p->min_linear), p->max_linear);
  }

  // get fast magnitude
  mag = p->magnitudes[p->fast];

  // compute raw fast gain
  lin = mag ? p->fast_target_level / mag : p->fast_now_linear;
  if (lin > p->fast_now_linear) {
    // if the linear gain is greater than the current fast gain
    if (--p->fast_hang_count < 0) {
      // fast hang time window expired, compute decayed fast linear gain
      p->fast_now_linear = minf(p->fast_one_m_decay * p->fast_now_linear + p->fast_decay * minf(p->max_linear, lin), p->max_linear);
      // clamp to the min and the max linear gain
      p->fast_now_linear = minf(maxf(p->fast_now_linear, p->min_linear), p->max_linear);
    }
  } else {
    // restart the fast hang time window
    p->fast_hang_count = p->fast_hang_samples;
    // compute the attacked fast linear gain
    p->fast_now_linear = maxf(p->fast_one_m_attack * p->fast_now_linear + p->attack * maxf(p->min_linear, lin), p->min_linear);
    // clamp to the min and the max linear gain
    p->fast_now_linear = minf(maxf(p->fast_now_linear, p->min_linear), p->max_linear);
  }

  // compute the output sample gain
  lin = minf(p->fast_now_linear, minf(p->slope * p->now_linear, p->max_linear));

  // compute the output sample
  z = lin * p->samples[p->out];

  // advance ring buffer indices
  p->in -= 1; p->in &= p->mask;
  p->out -= 1; p->out &= p->mask;
  p->fast -= 1; p->fast &= p->mask;

  // return sample
  return z;
}
#endif

