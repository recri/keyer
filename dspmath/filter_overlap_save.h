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
**
** We can either throw away the left hand side
** or the right hand side.
*/
#define LHS 0			

#include "dspmath.h"
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
  // options which may be altered ad lib
  int length;			/* length of chunk to process */
  int planbits;			/* plan bits for fftw */
  int sample_rate;		/* sample rate */
  int window;			/* filter window */
  float high_frequency;		/* high cutoff of bandpass */
  float low_frequency;		/* low cutoff of bandpass */
  // derived options
  int fmodified;		// marks new zfilter value
  float complex *zfilter;	/* new value for zfilter */
  int lmodified;		// marks new filter length
  float complex *zinput;	// new value for zinput
  fftwf_plan pfwd;		/* plan for transform zinput -> zsignal */
  float complex *zsignal;	// new value for zsignal
  fftwf_plan pinv;		/* plan for transform zsignal -> zoutput */
  float complex *zoutput;	// new value for zoutput
} filter_overlap_save_options_t;

typedef struct {
  int length;			/* length of chunk */
  int fftlen;			/* length of fft */
  int planbits;			/* plan bits for fftw */
  int sample_rate;		/* sample rate */
  int window;			/* filter window */
  float high_frequency;		/* high cutoff of bandpass */
  float low_frequency;		/* low cutoff of bandpass */
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
  // values to be cleaned up at next opportunity
  float complex *xzfilter;
  float complex *xzinput;
  float complex *xzsignal;
  float complex *xzoutput;
} filter_overlap_save_t;

/* configure installs a new transformed filter kernel */
static void filter_overlap_save_configure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  if (q->fmodified) {
    q->fmodified = 0;
    p->xzfilter = p->zfilter; p->zfilter = q->zfilter; q->zfilter = NULL;
    p->high_frequency = q->high_frequency;
    p->low_frequency = q->low_frequency;
  }
  if (q->lmodified) {
    q->lmodified = 0;
    p->xzinput = p->zinput; p->zinput = q->zinput; q->zinput = NULL;
    p->pfwd = q->pfwd; q->pfwd = NULL;
    p->xzsignal = p->zsignal; p->zsignal = q->zsignal; q->zsignal = NULL;
    p->pinv = q->pinv; q->pinv = NULL;
    p->xzoutput = p->zoutput; p->zoutput = q->zoutput; q->zoutput = NULL;
    p->length = q->length;
    p->fftlen = 2*q->length;
    p->planbits = q->planbits;
    p->sample_rate = q->sample_rate;
    p->window = q->window;
    p->input_index = p->length;
    p->input_limit = p->fftlen;
    p->output_index = LHS ? p->length : 0;
    p->scale = 1.0 / p->fftlen;
  }
}

static void filter_overlap_save_xcleanup(filter_overlap_save_t *p) {
  if (p->xzinput != NULL) fftwf_free(p->xzinput); p->xzinput = NULL;
  if (p->xzfilter != NULL) fftwf_free(p->xzfilter); p->xzfilter = NULL;
  if (p->xzsignal != NULL) fftwf_free(p->xzsignal); p->xzsignal = NULL;
  if (p->xzoutput != NULL) fftwf_free(p->xzoutput); p->xzoutput = NULL;
}

static void filter_overlap_save_delete(filter_overlap_save_t *p) {
  filter_overlap_save_xcleanup(p);
  if (p->zinput != NULL) fftwf_free(p->zinput); p->zinput = NULL;
  if (p->zfilter != NULL) fftwf_free(p->zfilter); p->zfilter = NULL;
  if (p->zsignal != NULL) fftwf_free(p->zsignal); p->zsignal = NULL;
  if (p->zoutput != NULL) fftwf_free(p->zoutput); p->zoutput = NULL;
  if (p->pfwd != NULL) fftwf_destroy_plan(p->pfwd); p->pfwd = NULL;
  if (p->pinv != NULL) fftwf_destroy_plan(p->pinv); p->pinv = NULL;
}

static void *filter_overlap_save_preconfigure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  // fprintf(stderr, "filter_overlap_save_preconfigure: started\n");
  filter_overlap_save_xcleanup(p);
  int fmodified = 0, lmodified = 0;
  if (q->length < 8)
    return (void *)"buffer length is too small";
  if ((q->length & 1) != 0)
    q->length -= 1;
  if (fabsf(q->low_frequency) >= q->sample_rate / 2)
    return (void *)"low frequency is too high for sample rate";
  if (fabsf(q->high_frequency) >= q->sample_rate / 2)
    return (void *)"high frequency is too high for sample rate";
  if ((q->low_frequency + 10) >= q->high_frequency)
    return (void *)"bandwidth is too narrow";
  // preconfigure length and frequency
  if (q->length != p->length ||
      q->sample_rate != p->sample_rate ||
      q->planbits != p->planbits) {
    lmodified = 1;
    fmodified = 1;
  }
  // preconfigure frequency
  if (q->low_frequency != p->low_frequency ||
      q->high_frequency != p->high_frequency) {
    fmodified = 1;
  }
  // fft length
  int fftlen = 2*q->length;
  // number of filter coefficients
  int ncoef = q->length+1;

  if (fmodified) {
    // fprintf(stderr, "filter_overlap_save_preconfigure: freq modified\n");
    float complex *zkernel = fftwf_malloc(fftlen*sizeof(float complex));
    if (zkernel == NULL)
      return (void *)"memory allocation failure #2";
    if (q->zfilter == NULL) {
      q->zfilter = fftwf_malloc(fftlen*sizeof(float complex));
      if (q->zfilter == NULL) {
	fftwf_free(zkernel);
	return (void *)"memory allocation failure #3";
      }
    }
    fftwf_plan pkernel = fftwf_plan_dft_1d(fftlen, zkernel, q->zfilter, FFTW_FORWARD, q->planbits);
    if (pkernel == NULL) {
      fftwf_free(zkernel);
      return (void *)"memory allocation failure #4";
    }
    float complex *filter;
    // write filter coeffs into the left hand side of fft input, pad with zeroes on the right
    // write filter coeffs into the right hand side of fft input, pad with zeroes on the left
    complex_vector_clear(zkernel, fftlen);
    filter = zkernel + (LHS ? 0 : (fftlen-ncoef));
    void *e = bandpass_complex(q->low_frequency, q->high_frequency, q->sample_rate, ncoef, q->window,filter); if (e != filter) {
      fftwf_destroy_plan(pkernel);
      fftwf_free(zkernel);
      return e;
    }
  
    fftwf_execute(pkernel);
    fftwf_destroy_plan(pkernel);
    fftwf_free(zkernel);
    // fprintf(stderr, "ovsv max_abs before normalization = %.5f\n", complex_vector_max_abs(q->zfilter, fftlen));
    complex_vector_normalize(q->zfilter, q->zfilter, fftlen);
    // fprintf(stderr, "ovsv max_abs after normalization = %.5f\n", complex_vector_max_abs(q->zfilter, fftlen));
    q->fmodified = 1;
  }
  if (lmodified) {
    // fprintf(stderr, "filter_overlap_save_preconfigure: length modified\n");
    if ((q->zinput = (float complex *)fftwf_malloc(fftlen*sizeof(float complex))) == NULL ||
	(q->zsignal = (float complex *)fftwf_malloc(fftlen*sizeof(float complex))) == NULL ||
	(q->zoutput = (float complex *)fftwf_malloc(fftlen*sizeof(float complex))) == NULL ||
	(q->pfwd = fftwf_plan_dft_1d(fftlen, q->zinput, q->zsignal, FFTW_FORWARD, q->planbits)) == NULL ||
	(q->pinv = fftwf_plan_dft_1d(fftlen, q->zsignal, q->zoutput, FFTW_BACKWARD, q->planbits)) == NULL) {
      filter_overlap_save_delete(p);
      return "memory allocation failure #1";
    }
    q->lmodified = 1;
  }
  return p;
}

static void *filter_overlap_save_init(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  memset(p, 0, sizeof(filter_overlap_save_t));
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
    complex_vector_multiply(p->zsignal, p->zsignal, p->zfilter, p->fftlen);
    /* inverse transform */
    fftwf_execute(p->pinv);
    /* scale result */
    complex_vector_scale(p->zoutput, p->zoutput, p->scale, p->fftlen);
    /* shift input block */
    complex_vector_copy(p->zinput, p->zinput+p->length, p->length);
    /* reset input and output indexes */
    p->input_index = p->length;
    p->output_index = LHS ? p->length : 0;
  }
  return p->zoutput[p->output_index++];
}
#endif
