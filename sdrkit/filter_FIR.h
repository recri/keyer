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
#ifndef FILTER_FIR_H
#define FILTER_FIR_H

#include "dmath.h"
#include "window.h"

/*
** construct the coefficients for a FIR filter
**
** taken from dttsp/src/filter.c
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
** Doxygen comments added by Dave Larsen, KV0S
*/

/*
** bandpass and bandstop are complements, lowpass and highpass are complements.
*/
static void *complement_real(int size, float *coeff) {
  int midpoint = (size >> 01) | 01;
  for (int i = 0; i < size; i += 1) coeff[i] = - coeff[i];
  coeff[midpoint] += 1.0f;
  return coeff;
}

static void *bandpass_real(float lo, float hi, float sr, int size, float *coeff) {
  if ((lo < 0.0) || (hi > (sr / 2.0)) || (hi <= lo))
    return (void *)"lo frequency and/or hi frequency out of bounds";
  if (size < 1) return (void *)"size too small";
  if ((size&1) == 0) return (void *)"size not odd";
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = (hi - lo) / 2.0f;
  float ff = ((lo + hi) * pi);

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) *
	window_get(WINDOW_BLACKMANHARRIS, size, j) *
	2.0f * cosf(ff * k);
    else
      coeff[j] = 2.0f * fc * 2.0f * cosf(ff * k);
  }
  return coeff;
}

static void *bandstop_real(float lo, float hi, float sr, int size, float *coeff) {
  void *e = bandpass_real(lo, hi, sr, size, coeff);
  if (e != coeff) return e;
  return complement_real(size, coeff);
}

static void *hilbert_real(float lo, float hi, float sr, int size, float *coeff) {
  if ((lo < 0.0) || (hi > (sr / 2.0)) || (hi <= lo))
    return (void *)"lo frequency and/or hi frequency out of bounds";
  if (size < 1) return (void *)"size too small";
  if ((size&1) == 0) return (void *)"size not odd";
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = (hi - lo) / 2.0f;
  float ff = ((lo + hi) * pi);

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) *
	window_get(WINDOW_BLACKMANHARRIS, size, j) *
	2.0f * sinf(ff * k);
    else
      coeff[j] = 2.0f * fc * 2.0f * sinf(ff * k);
  }
  return coeff;
}  

/*
** a lowpass real filter is used to implement polyphase spectra
*/
static void *lowpass_real(float cutoff, float sr, int size, float *coeff) {
  if ((cutoff < 0.0) || (cutoff > (sr / 2.0))) return (void *)"cutoff out of range";
  if (size < 1) return (void *)"size too small";
  if ((size & 1) == 0) return (void *)"size not odd";
  float fc = cutoff / sr;
  int midpoint = (size >> 01) | 01;
  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMANHARRIS, size, j);
    else
      coeff[j] = 2.0f * fc;
  }
  return (void *)coeff;
}

static void *highpass_real(float cutoff, float sr, int size, float *coeff) {
  void *e = lowpass_real(cutoff, sr, size, coeff);
  if (e != coeff) return e;
  return complement_real(size, coeff);
}

/*
** a complex bandpass filter is used to implement the radio bandpass
*/
static void *bandpass_complex(float lo, float hi, float sr, int size, float complex *coeff) {
  if ((lo < -(sr / 2.0)) || (hi > (sr / 2.0)) || (hi <= lo))
    return (void *)"lo frequency and/or hi frequency out of bounds";
  if (size < 1) return (void *)"size too small";
  if ((size&1) == 0) return (void *)"size not odd";

  float fc;
  float ff;
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  fc = (hi - lo) / 2.0f;
  ff = (lo + hi) * pi;

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    float tmp, phs = ff * k;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) *
	window_get(WINDOW_BLACKMANHARRIS, size, j) *
	2.0f * (cosf(phs) + I * sinf(phs)); // is this a complex trig function?
    else
      coeff[j] = 2.0f * fc * 2.0f *(cosf(phs) + I * sinf(phs));
  }
  return (void *)coeff;
}

static void *bandstop_complex(float lo, float hi, float sr, int size, float complex *coeff) {
  void *e = bandpass_complex(lo, hi, sr, size, coeff);
  if (e != coeff) return e;
  int midpoint = (size >> 01) | 01;
  for (int i = 1; i <= size; i += 1)
    if (i == midpoint)
      coeff[i-1] = 1.0f - coeff[i-1];
    else
      coeff[i-1] = - coeff[i-1];
  return (void *)coeff;
}
  
static void *hilbert_complex(float lo, float hi, float sr, int size, float complex *coeff) {
#if 0
/* -------------------------------------------------------------------------- */
/** @brief Create new Hilbert COMPLEX FIR 
* 
* @param lo 
* @param hi 
* @param sr 
* @param size 
*/
/* ---------------------------------------------------------------------------- */
ComplexFIR
newFIR_Hilbert_COMPLEX(REAL lo, REAL hi, REAL sr, int size) {
  if ((lo < 0.0) || (hi > (sr / 2.0)) || (hi <= lo))
    return 0;
  else if (size < 1)
    return 0;
  else {
    ComplexFIR p;
    COMPLEX *h;
    REAL *w, fc, ff;
    int i, midpoint;

    if (!(size & 01))
      size++;
    midpoint = (size >> 01) | 01;
    p = newFIR_COMPLEX(size, "newFIR_Hilbert_COMPLEX");
    h = FIRcoef(p);
    w = newvec_REAL(size, "newFIR_Hilbert_COMPLEX window");
    (void) makewindow(BLACKMANHARRIS_WINDOW, size, w);

    lo /= sr, hi /= sr;
    fc = (REAL) ((hi - lo) / 2.0);
    ff = (REAL) ((lo + hi) * onepi);

    for (i = 1; i <= size; i++) {
      int j = i - 1;
      REAL tmp, phs = ff * (i - midpoint);
      if (i != midpoint)
	tmp =
	  (REAL) ((sin(twopi * (i - midpoint) * fc) /
		   (onepi * (i - midpoint))) * w[j]);
      else
	tmp = (REAL) (2.0 * fc);
      tmp *= 2.0f;
      /* h[j].re *= tmp * cos(phs); */
      h[j].im *= (REAL) (tmp * sin(phs));
    }

    delvec_REAL(w);
    FIRtype(p) = FIR_Hilbert;
    return p;
  }
}
#else
  return (void *)"complex hilbert filter not implemented";
#endif
}
  
static void *lowpass_complex(float cutoff, float sr, int size, float complex *coeff) {
#if 0
/* -------------------------------------------------------------------------- */
/** @brief Create new Lowpass COMPLEX FIR 
* 
* @param cutoff 
* @param sr 
* @param size 
*/
/* ---------------------------------------------------------------------------- */
ComplexFIR
newFIR_Lowpass_COMPLEX(REAL cutoff, REAL sr, int size) {
  if ((cutoff < 0.0) || (cutoff > (sr / 2.0)))
    return 0;
  else if (size < 1)
    return 0;
  else {
    ComplexFIR p;
    COMPLEX *h;
    REAL *w, fc = cutoff / sr;
    int i, midpoint;

    if (!(size & 01))
      size++;
    midpoint = (size >> 01) | 01;
    p = newFIR_COMPLEX(size, "newFIR_Lowpass_COMPLEX");
    h = FIRcoef(p);
    w = newvec_REAL(size, "newFIR_Lowpass_REAL window");
    (void) makewindow(BLACKMANHARRIS_WINDOW, size, w);

    for (i = 1; i <= size; i++) {
      int j = i - 1;
      if (i != midpoint)
	h[j].re =
	  (REAL) ((sin(twopi * (i - midpoint) * fc) /
		   (onepi * (i - midpoint))) * w[j]);
      else
	h[midpoint - 1].re = 2.0f * fc;
    }

    delvec_REAL(w);
    FIRtype(p) = FIR_Lowpass;
    return p;
  }
}
#else
  return (void *)"complex lowpass filter not implemented";
#endif  
}

static void *highpass_complex(float cutoff, float sr, int size, float complex *coeff) {
#if 0
/* -------------------------------------------------------------------------- */
/** @brief Create new Highpass COMPLEX FIR 
* 
* @param cutoff 
* @param sr 
* @param size 
*/
/* ---------------------------------------------------------------------------- */
ComplexFIR
newFIR_Highpass_COMPLEX(REAL cutoff, REAL sr, int size) {
  if ((cutoff < 0.0) || (cutoff > (sr / 2.0)))
    return 0;
  else if (size < 1)
    return 0;
  else {
    ComplexFIR p;
    COMPLEX *h;
    REAL *w, fc = cutoff / sr;
    int i, midpoint;

    if (!(size & 01))
      size++;
    midpoint = (size >> 01) | 01;
    p = newFIR_COMPLEX(size, "newFIR_Highpass_REAL");
    h = FIRcoef(p);
    w = newvec_REAL(size, "newFIR_Highpass_REAL window");
    (void) makewindow(BLACKMANHARRIS_WINDOW, size, w);

    for (i = 1; i <= size; i++) {
      int j = i - 1;
      if (i != midpoint)
	h[j].re =
	  (REAL) ((sin(twopi * (i - midpoint) * fc) /
		   (onepi * (i - midpoint))) * w[j]);
      else
	h[midpoint - 1].re = (REAL) (2.0 * fc);
    }

    for (i = 1; i <= size; i++) {
      int j = i - 1;
      if (i != midpoint)
	h[j].re = -h[j].re;
      else
	h[midpoint - 1].re = (REAL) (1.0 - h[midpoint - 1].re);
    }

    delvec_REAL(w);
    FIRtype(p) = FIR_Highpass;
    return p;
  }
}
#else
  return (void *)"complex highpass filter not implemented";
#endif
}

#endif
