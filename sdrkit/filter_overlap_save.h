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
#ifndef FILTER_OVERLAP_SAVE_H
#define FILTER_OVERLAP_SAVE_H

/*
** this determines where new inputs get stored
** and where outputs end up.  We do the fft on
** twice the number of samples required for the
** filter and throw half the results away.
*/
#define LHS 0			

#include "dmath.h"
#include "filter_FIR.h"
#include <fftw3.h>

/*
** Overlap-save filter.
**
** You can find Overlap-Add discussed in Chapter 19, starting on page 311
** in The Scientist and Engineer's Guide to Digital Signal Processing
** by Steven W. Smith, http://www.dspguide.com/.
**
** Overlap-save is also called overlap-discard or overlap-scrap because
** it discards stuff at each iteration, rather than combining the results
** of adjacent iterations as in overlap-add.  
**
** We are transforming the kernel for a FIR band pass filter into the
** frequency domain.
** We take our signal in chunks, transform it into the frequency domain,
** convolve with the transformed filter, and reverse transform the
** convolution back to the time domain.
**
** Wikipedia says that we could also do frequency mixing, by resorting our
** frequency bins, or sample rate conversion, by mixing different size ffts,
** in the same computation.  Also, if you want to filter out more than one
** channel, then share the forward transform between the channels.
*/

typedef struct {
  int length;			/* length of chunk to process, fixed at creation */
  int planbits;			/* plan bits for fftw, fixed at creation */
  float high_frequency;		/* high cutoff of bandpass */
  float low_frequency;		/* low cutoff of bandpass */
  int sample_rate;		/* sample rate, fixed at creation */
  // derived options
  float complex *zfilter;	/* new value for zfilter */
} filter_overlap_save_options_t;

typedef struct {
  int length;			/* length of chunk */
  int fftlen;			/* length of fft */
  int planbits;			/* plan bits for fftw */
  float complex *zinput;	/* incoming signal buffer */
  fftwf_plan pfwd;		/* plan for transform zinput -> zsignal */
  float complex *zfilter;	/* forward transformed filter kernel */
  float complex *zsignal;	/* forward transformed and subsequently convolved signal */
  fftwf_plan pinv;		/* plan for transform zsignal -> zoutput */
  float complex *zoutput;	/* outgoing signal buffer */
  float scale;			/* normalization factor for fft round trip */
  int input_limit;		/* number of signals until next transform */
  int input_index; 		/* where the next signal goes in zinput */
  int output_index;		/* where the next signal is in zoutput */
} filter_overlap_save_t;

/* configure installs a new transformed filter kernel */
static void filter_overlap_save_configure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  complex_vector_copy(p->zfilter, q->zfilter, p->fftlen);
}

static void *filter_overlap_save_preconfigure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  if (q->length != p->length)
    return (void *)"overlap save length cannot be altered";
  if (fabsf(q->low_frequency) >= q->sample_rate / 2)
    return (void *)"low frequency is too high for sample rate";
  if (fabsf(q->high_frequency) >= q->sample_rate / 2)
    return (void *)"high frequency is too high for sample rate";
  if ((q->low_frequency + 10) >= q->high_frequency)
    return (void *)"bandwidth is too narrow";
  int ncoef = q->length+1;
  float complex *zkernel = fftw_malloc(p->fftlen*sizeof(float complex));
  if (zkernel == NULL)
    return (void *)"memory allocation failure #2";
  complex_vector_clear(zkernel, p->fftlen);
  if (q->zfilter == NULL) {
    q->zfilter = fftw_malloc(p->fftlen*sizeof(float complex));
    if (q->zfilter == NULL) {
      fftw_free(zkernel);
      return (void *)"memory allocation failure #3";
    }
  }
  fftwf_plan pkernel = fftwf_plan_dft_1d(p->fftlen, zkernel, q->zfilter, FFTW_FORWARD, p->planbits);
  if (pkernel == NULL) {
    fftw_free(zkernel);
    return (void *)"memory allocation failure #4";
  }
  float complex *filter;
#if LHS
  // write filter coeffs into the left hand side of fft input, pad with zeroes on the right
  filter = zkernel;
#else
  // write filter coeffs into the right hand side of fft input, pad with zeroes on the left
  filter = zkernel+p->fftlen-ncoef;
#endif
  void *e = bandpass_complex(q->low_frequency, q->high_frequency, q->sample_rate, ncoef, filter); if (e != filter) {
    fftwf_destroy_plan(pkernel);
    fftwf_free(zkernel);
    return e;
  }
  fftwf_execute(pkernel);
  fftwf_destroy_plan(pkernel);
  fftwf_free(zkernel);
  return p;
}

static void filter_overlap_save_delete(filter_overlap_save_t *p) {
  if (p->zinput != NULL) fftwf_free(p->zinput); p->zinput = NULL;
  if (p->zfilter != NULL) fftwf_free(p->zfilter); p->zfilter = NULL;
  if (p->zsignal != NULL) fftwf_free(p->zsignal); p->zsignal = NULL;
  if (p->zoutput != NULL) fftwf_free(p->zoutput); p->zoutput = NULL;
  if (p->pfwd != NULL) fftwf_destroy_plan(p->pfwd); p->pfwd = NULL;
  if (p->pinv != NULL) fftwf_destroy_plan(p->pinv); p->pinv = NULL;
}

static void *filter_overlap_save_init(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  memset(p, 0, sizeof(filter_overlap_save_t));
  if (q->length < 8) return (void *)"buffer length is too small";
  if ((q->length & 1) != 0) return (void *)"buffer length is odd";
  p->length = q->length;
  p->fftlen = 2*q->length;
  p->planbits = q->planbits;
  p->input_index = p->length;
  p->input_limit = p->fftlen;
#if LHS
  p->output_index = p->length;
#else  
  p->output_index = 0;
#endif
  if ((p->zinput = (float complex *)fftwf_malloc(p->fftlen*sizeof(float complex))) == NULL ||
      (p->zfilter = (float complex *)fftwf_malloc(p->fftlen*sizeof(float complex))) == NULL ||
      (p->zsignal = (float complex *)fftwf_malloc(p->fftlen*sizeof(float complex))) == NULL ||
      (p->zoutput = (float complex *)fftwf_malloc(p->fftlen*sizeof(float complex))) == NULL ||
      (p->pfwd = fftwf_plan_dft_1d(p->fftlen, p->zinput, p->zsignal, FFTW_FORWARD, p->planbits)) == NULL ||
      (p->pinv = fftwf_plan_dft_1d(p->fftlen, p->zsignal, p->zoutput, FFTW_BACKWARD, p->planbits)) == NULL) {
    filter_overlap_save_delete(p);
    return "memory allocation failure #1";
  }
  p->scale = 1.0 / fftlen;
  void *e = filter_overlap_save_preconfigure(p, q); if (e != p) return e;
  filter_overlap_save_configure(p, q);
  return p;
}

static float complex filter_overlap_save_process(filter_overlap_save_t *p, float complex x) {
  p->zinput[p->input_index++] = x;
  if (p->input_index == p->input_limit) {
    /* forward transform */
    fftwf_execute(p->pfwd);
    /* convolve with transformed filter kernel */
    complex_vector_muliply(p->zsignal, p->zsignal, p->zfilter, p->fftlen);
    /* inverse transform */
    fftwf_execute(p->pinv);
    /* scale result */
    complex_vector_scale(p->zoutput, p->zoutput, p->scale, p->buflen);
    /* shift input block */
    complex_vector_copy(p->zinput, p->zinput+p->buflen, p->buflen);
    p->input_index = p->buflen;
#if LHS
    p->output_index = p->length;
#else  
    p->output_index = 0;
#endif
  }
  return p->zoutput[p>output_index++];
}
#endif
