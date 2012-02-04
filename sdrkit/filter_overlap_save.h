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
  int length;			/* length of chunk to process */
  float high_frequency;		/* high cutoff of bandpass */
  float low_frequency;		/* low cutoff of bandpass */
  int sample_rate;		/* sample rate we're operating at */
  float complex *zfilter;	/* new value for zfilter */
} filter_overlap_save_options_t;

typedef struct {
  int length;			/* length of chunk */
  int fftlen;			/* length of fft */
  float complex *zinput;	/* incoming signal buffer */
  fftwf_plan pfwd;		/* plan for transform zinput -> zsignal */
  float complex *zfilter;	/* forward transformed filter kernel */
  float complex *zsignal;	/* forward transformed and subsequently convolved signal */
  fftwf_plan pinv;		/* plan for transform zsignal -> zoutput */
  float complex *zoutput;	/* outgoing signal buffer */
  int n_to_fill;		/* number of signals until next transform */
  int i_to_fill; 		/* where the next signal goes in zinput */
  int i_to_take;		/* where the next signal is in zoutput */
} filter_overlap_save_t;

/* configure installs a new transformed filter kernel */
static void filter_overlap_save_configure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  memcpy(p->zfilter, q->zfilter, q->length*sizeof(float complex));
  return p;
}

static void *filter_overlap_save_preconfigure(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  if (fabsf(q->low_frequency) >= q->sample_rate / 2)
    return (void *)"low frequency is too high for sample rate";
  if (fabsf(q->high_frequency) >= q->sample_rate / 2)
    return (void *)"high frequency is too high for sample rate";
  if ((q->low_frequency + 10) >= q->high_frequency)
    return (void *)"bandwidth is too narrow";
  if (q->zfilter == NULL)
    q->zfilter = fftwf_malloc(q->length*sizeof(float complex));
  if (q->zfilter == NULL)
    return (void *)"memory allocation failure";
  float complex *zkernel = fftw_malloc(q->length*sizeof(float complex));
  if (zkernel == NULL) {
    fftwf_free(q->zfilter);
    return (void *)"memory allocation failure";
  }
  fftwf_plan pkernel;
  return p;
}

static void *filter_overlap_save_init(filter_overlap_save_t *p, filter_overlap_save_options_t *q) {
  return p;
}

static float complex filter_overlap_save_process(filter_overlap_save_t *p, float complex x) {
}


#if 0
/* ovsv.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY

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
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

The authors can be reached by email at

ab2kt@arrl.net
or
rwmcgwier@gmail.com

or by paper mail at

The DTTS Microwave Society
6 Kathleen Place
Bridgewater, NJ 08807
*/

#ifndef _ovsv_h
#define _ovsv_h

#include <fromsys.h>
#include <banal.h>
#include <splitfields.h>
#include <datatypes.h>
#include <bufvec.h>
#include <cxops.h>
#include <update.h>
#include <lmadf.h>
#include <fftw3.h>

typedef struct _filt_ov_sav {
  int buflen, fftlen;
  COMPLEX *zfvec, *zivec, *zovec, *zrvec;
  fftwf_plan pfwd, pinv;
  REAL scale;
} filt_ov_sv, *FiltOvSv;

extern FiltOvSv newFiltOvSv(COMPLEX *coefs, int ncoef, int pbits);
extern void delFiltOvSv(FiltOvSv p);

extern COMPLEX *FiltOvSv_initpoint(FiltOvSv pflt);
extern int FiltOvSv_initsize(FiltOvSv pflt);

extern COMPLEX *FiltOvSv_fetchpoint(FiltOvSv pflt);
extern int FiltOvSv_fetchsize(FiltOvSv pflt);

extern COMPLEX *FiltOvSv_storepoint(FiltOvSv pflt);
extern int FiltOvSv_storesize(FiltOvSv pflt);

extern void filter_OvSv(FiltOvSv pflt);
extern void reset_OvSv(FiltOvSv pflt);

#endif
/** 
* @file ovsv.c
* @brief Functions to implement the OvSv filter 
* @author Frank Brickle, AB2KT and Bob McGwier, N4HY

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2007 by Frank Brickle, AB2KT and Bob McGwier, N4HY
Doxygen comments added by Dave Larsen, KV0S

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

The authors can be reached by email at

ab2kt@arrl.net
or
rwmcgwier@gmail.com

or by paper mail at

The DTTS Microwave Society
6 Kathleen Place
Bridgewater, NJ 08807
*/

#include <ovsv.h>


/*------------------------------------------------------------*/

/* -------------------------------------------------------------------------- */
/** @brief Run OvSV filter
 *
 * @param pflt 
 * @return 
 */
/* ---------------------------------------------------------------------------- */
/* run the filter */

void
filter_OvSv(FiltOvSv pflt) {
  int i, m = pflt->fftlen, n = pflt->buflen;
  COMPLEX *zfvec = pflt->zfvec,
          *zivec = pflt->zivec,
          *zovec = pflt->zovec,
          *zrvec = pflt->zrvec;
  REAL scl = pflt->scale;

  /* input sig -> z */
  fftwf_execute(pflt->pfwd);

#ifdef __SSE3__
  CmulSSE3(zivec, zivec, zfvec, m);
#else
  /* convolve in z */
  for (i = 0; i < m; i++)
    zivec[i] = Cmul(zivec[i], zfvec[i]);
#endif
  /* z convolved sig -> time output sig */
  fftwf_execute(pflt->pinv);

  /* scale */
  for (i = 0; i < n; i++)
    zovec[i].re *= scl, zovec[i].im *= scl;

  /* prepare input sig vec for next fill */
  memcpy((char *) zrvec, (char *) &zrvec[n], n * sizeof(COMPLEX));
}

/* -------------------------------------------------------------------------- */
/** @brief Reset the OvSv Filter 
* 
* @param pflt 
* @return 
*/
/* ---------------------------------------------------------------------------- */
void
reset_OvSv(FiltOvSv pflt) {
  memset((char *) pflt->zrvec, 0, pflt->fftlen * sizeof(COMPLEX));
}

/* -------------------------------------------------------------------------- */
/** @brief Initial point OvSv filter  
* 
* NB strategy. This is the address we pass to newCXB as
* the place to read samples into. It's the right half of
* the true buffer. Old samples get slid from here to
* left half after each go-around. 
*
* @param pflt 
* @return 
*/
/* ---------------------------------------------------------------------------- */
COMPLEX *
FiltOvSv_initpoint(FiltOvSv pflt) {
  return &(pflt->zrvec[pflt->buflen]);
}

/* -------------------------------------------------------------------------- */
/** @brief inital size for the OvSv filter 
* 
* how many to put there 
*
* @param pflt 
* @return 
*/
/* ---------------------------------------------------------------------------- */
int
FiltOvSv_initsize(FiltOvSv pflt) {
  return (pflt->fftlen - pflt->buflen);
}

/* -------------------------------------------------------------------------- */
/** @brief Fetch point from the OvSv filter 
* 
* where to put next batch of samples to filter 
*
* @param pflt 
* @return *COMPLEX
*/
/* ---------------------------------------------------------------------------- */
COMPLEX *
FiltOvSv_fetchpoint(FiltOvSv pflt) {
  return &(pflt->zrvec[pflt->buflen]);
}

/* -------------------------------------------------------------------------- */
/** @brief Fetch size from OvSv filter 
* 
* how many samples to put there 
*
* @param pflt 
* @return int
*/
/* ---------------------------------------------------------------------------- */
int
FiltOvSv_fetchsize(FiltOvSv pflt) {
  return (pflt->fftlen - pflt->buflen);
}

#ifdef LHS
/* -------------------------------------------------------------------------- */
/** @brief Store point OvSv Filter 
* 
* where samples should be taken from after filtering 
*
* @param pflt 
* @return *COMPLEX
*/
/* ---------------------------------------------------------------------------- */
COMPLEX *
FiltOvSv_storepoint(FiltOvSv pflt) {
  return ((pflt->zovec) + pflt->buflen);
}
#else
/* -------------------------------------------------------------------------- */
/** @brief Store point OvSv Filter 
* 
* @param pflt 
* @return *COMPLEX
*/
/* ---------------------------------------------------------------------------- */
COMPLEX *
FiltOvSv_storepoint(FiltOvSv pflt) {
  return ((pflt->zovec));
}
#endif

/* -------------------------------------------------------------------------- */
/** @brief Store size in the OvSv filter 
* 
* how many samples to take 
* NB strategy. This is the number of good samples in the
* left half of the true buffer. Samples in right half
* are circular artifacts and are ignored.
*
* @param pflt 
* @return int
*/
/* ---------------------------------------------------------------------------- */
int
FiltOvSv_storesize(FiltOvSv pflt) {
  return (pflt->fftlen - pflt->buflen);
}


/* -------------------------------------------------------------------------- */
/** @brief Create a new OvSv filter 
* 
* create a new overlap/save filter from complex coefficients 
*
* @param coefs 
* @param ncoef 
* @param pbits 
* @return FiltOvSv
*/
/* ---------------------------------------------------------------------------- */
FiltOvSv
newFiltOvSv(COMPLEX *coefs, int ncoef, int pbits) {
  int buflen, fftlen;
  FiltOvSv p;
  fftwf_plan pfwd, pinv;
  COMPLEX *zrvec, *zfvec, *zivec, *zovec;
  
  p = (FiltOvSv) safealloc(1, sizeof(filt_ov_sv), "new overlap/save filter");
  buflen = nblock2(ncoef - 1);
  fftlen = 2 * buflen;

  zrvec = newvec_COMPLEX_fftw(fftlen, "raw signal vec in newFiltOvSv");
  zfvec = newvec_COMPLEX_fftw(fftlen, "filter z vec in newFiltOvSv");
  zivec = newvec_COMPLEX_fftw(fftlen, "signal in z vec in newFiltOvSv");
  zovec = newvec_COMPLEX_fftw(fftlen, "signal out z vec in newFiltOvSv");

  /* prepare frequency response from filter coefs */
  {
    int i;
    COMPLEX *zcvec;
    fftwf_plan ptmp;

    zcvec = newvec_COMPLEX(fftlen, "temp filter z vec in newFiltOvSv");
    ptmp =
      fftwf_plan_dft_1d(fftlen,
			(fftwf_complex *) zcvec,
			(fftwf_complex *) zfvec,
			FFTW_FORWARD,
			pbits);

#ifdef LHS
    for (i = 0; i < ncoef; i++)
      zcvec[i] = coefs[i];
#else
    for (i = 0; i < ncoef; i++)
      zcvec[fftlen - ncoef + i] = coefs[i];
#endif

    fftwf_execute(ptmp);
    fftwf_destroy_plan(ptmp);
    delvec_COMPLEX(zcvec);
  }

  /* prepare transforms for signal */
  pfwd = fftwf_plan_dft_1d(fftlen,
			   (fftwf_complex *) zrvec,
			   (fftwf_complex *) zivec,
			   FFTW_FORWARD,
			   pbits);
  pinv = fftwf_plan_dft_1d(fftlen,
			   (fftwf_complex *) zivec,
			   (fftwf_complex *) zovec,
			   FFTW_BACKWARD,
			   pbits);
  /* stuff values */
  p->buflen = buflen;
  p->fftlen = fftlen;
  p->zfvec = zfvec;
  p->zivec = zivec;
  p->zovec = zovec;
  p->zrvec = zrvec;
  p->pfwd = pfwd;
  p->pinv = pinv;
  p->scale = 1.0 / (REAL) fftlen;

  return p;
}

/* -------------------------------------------------------------------------- */
/** @brief Destroy a OvSv filter 
* 
* deep-six the filter 
*
* @param p 
* @return void
*/
/* ---------------------------------------------------------------------------- */
void
delFiltOvSv(FiltOvSv p) {
  if (p) {
    delvec_COMPLEX_fftw(p->zfvec);
    delvec_COMPLEX_fftw(p->zivec);
    delvec_COMPLEX_fftw(p->zovec);
    delvec_COMPLEX_fftw(p->zrvec);
    fftwf_destroy_plan(p->pfwd);
    fftwf_destroy_plan(p->pinv);
    safefree((char *) p);
  }
}

/*------------------------------------------------------------*/
/* -------------------------------------------------------------------------- */
/**
 * @file update.c
 */
/** @brief private setRXFilter 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXFilter(int n, char **p) {
  REAL low_frequency = atof(p[0]),
       high_frequency = atof(p[1]);
  int i, ncoef = rx[RL]->len + 1, fftlen = 2 * rx[RL]->len;
  fftwf_plan ptmp;
  COMPLEX *zcvec;

  if (fabs(low_frequency) >= 0.5 * uni->rate.sample)
    return -1;
  if (fabs(high_frequency) >= 0.5 * uni->rate.sample)
    return -2;
  if ((low_frequency + 10) >= high_frequency)
    return -3;
  delFIR_COMPLEX(rx[RL]->filt.coef);

#if 0
  fprintf(stderr, "setRXFilter %f %f\n", low_frequency, high_frequency);
#endif
  
  rx[RL]->filt.lo = low_frequency;
  rx[RL]->filt.hi = high_frequency;

  rx[RL]->filt.coef = newFIR_Bandpass_COMPLEX(low_frequency,
					      high_frequency,
					      uni->rate.sample,
					      ncoef);

  zcvec = newvec_COMPLEX(fftlen, "filter z vec in setFilter");
  ptmp = fftwf_plan_dft_1d(fftlen,
			   (fftwf_complex *) zcvec,
			   (fftwf_complex *) rx[RL]->filt.ovsv->zfvec,
			   FFTW_FORWARD,
			   uni->wisdom.bits);
#ifdef LHS
  for (i = 0; i < ncoef; i++)
    zcvec[i] = rx[RL]->filt.coef->coef[i];
#else
  for (i = 0; i < ncoef; i++)
    zcvec[fftlen - ncoef + i] = rx[RL]->filt.coef->coef[i];
#endif
  fftwf_execute(ptmp);
  fftwf_destroy_plan(ptmp);
  delvec_COMPLEX(zcvec);
  normalize_vec_COMPLEX(rx[RL]->filt.ovsv->zfvec, rx[RL]->filt.ovsv->fftlen);
  memcpy((char *) rx[RL]->filt.save, (char *) rx[RL]->filt.ovsv->zfvec,
	 rx[RL]->filt.ovsv->fftlen * sizeof(COMPLEX));

  return 0;
}
#endif
