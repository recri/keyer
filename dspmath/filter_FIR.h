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

#include "dspmath.h"
#include "window.h"

/*
** construct the coefficients for a FIR filter
**
** taken from dttsp/src/filter.c
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
** Doxygen comments added by Dave Larsen, KV0S
*/

/*
** the complex hilbert doesn't make sense,
** check both real and complex versions in original source
** the bounds checks on the complex highpass and lowpass are odd.
** complex highpass/lowpass are just real highpass/lowpass
*/

/*
** bandpass and bandstop are complements
** lowpass and highpass are complements.
*/
static void *complement_real(int size, float *coeff) {
  int midpoint = (size >> 01) | 01;
  for (int i = 0; i < size; i += 1) coeff[i] = - coeff[i];
  coeff[midpoint-1] += 1.0f;
  return coeff;
}

/*
** all real filters apply the same parameter checks
*/
static void *check_real(float lo, float hi, float sr, int size) {
  if ((lo < 0.0) || (hi > (sr / 2.0)) || (hi <= lo))
    return (void *)"lo frequency and/or hi frequency out of bounds";
  if (size < 1)
    return (void *)"size too small";
  if ((size&1) == 0)
    return (void *)"size not odd";
  return NULL;
}

static void *bandpass_real(float lo, float hi, float sr, int size, float *coeff) {
  void *e = check_real(lo, hi, sr, size); if (e != NULL) return e;
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = (hi - lo) / 2.0f;
  float ff = ((lo + hi) * pi);

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j) * 2.0f * cosf(ff * k);
    else
      coeff[j] = 2.0f * fc * 2.0f * cosf(ff * k);
  }
  return coeff;
}

static void *bandstop_real(float lo, float hi, float sr, int size, float *coeff) {
  void *e = bandpass_real(lo, hi, sr, size, coeff); if (e != coeff) return e;
  return complement_real(size, coeff);
}

static void *hilbert_real(float lo, float hi, float sr, int size, float *coeff) {
  void *e = check_real(lo, hi, sr, size); if (e != NULL) return e;
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = (hi - lo) / 2.0f;
  float ff = ((lo + hi) * pi);

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j) * 2.0f * sinf(ff * k);
    else
      coeff[j] = 2.0f * fc * 2.0f * sinf(ff * k);
  }
  return coeff;
}  

/*
** a lowpass real filter is used to implement polyphase spectra
*/
static void *lowpass_real(float cutoff, float sr, int size, float *coeff) {
  void *e = check_real(0.0f, cutoff, sr, size); if (e != NULL) return e;
  int midpoint = (size >> 01) | 01;
  float fc = cutoff / sr;
  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j);
    else
      coeff[j] = 2.0f * fc;
  }
  return (void *)coeff;
}

static void *highpass_real(float cutoff, float sr, int size, float *coeff) {
  void *e = lowpass_real(cutoff, sr, size, coeff); if (e != coeff) return e;
  return complement_real(size, coeff);
}

/*
** complex bandpass and bandstop are complements, complex lowpass and highpass are complements.
*/
static void *complement_complex(int size, float complex *coeff) {
  int midpoint = (size >> 01) | 01;
  for (int j = 0; j < size; j += 1) coeff[j] = - coeff[j];
  coeff[midpoint-1] += 1.0f;
  return (void *)coeff;
}

/*
** all complex filters apply the same parameter checks.
*/
static void *check_complex(float lo, float hi, float sr, int size) {
  if ((lo < -(sr / 2.0)) || (hi > (sr / 2.0)) || (hi <= lo))
    return (void *)"lo frequency and/or hi frequency out of bounds";
  if (size < 1)
    return (void *)"size too small";
  if ((size&1) == 0)
    return (void *)"size not odd";
  return NULL;
}

/*
** a complex bandpass filter is used to implement the radio bandpass
*/
static void *bandpass_complex(float lo, float hi, float sr, int size, float complex *coeff) {
  void *e = check_complex(lo, hi, sr, size); if (e != NULL) return e;
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = (hi - lo) / 2.0f;
  float ff = (lo + hi) * pi;

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    float phs = ff * k;
    if (i != midpoint)
      coeff[j] = (sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j) * 2.0f * cexpf(I * phs);
    else
      coeff[j] = 2.0f * fc * 2.0f * cexpf(I * phs);
  }
  return (void *)coeff;
}

static void *bandstop_complex(float lo, float hi, float sr, int size, float complex *coeff) {
  void *e = bandpass_complex(lo, hi, sr, size, coeff); if (e != coeff) return e;
  return complement_complex(size, coeff);
}
  
static void *hilbert_complex(float lo, float hi, float sr, int size, float complex *coeff) {
  void *e = check_complex(lo, hi, sr, size); if (e != NULL) return e;
  int midpoint = (size >> 01) | 01;
  lo /= sr, hi /= sr;
  float fc = ((hi - lo) / 2.0);
  float ff = ((lo + hi) * pi);

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    float tmp, phs = ff * k;
    if (i != midpoint)
      coeff[j] = 2.0f * ((sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j)) * sinf(phs) * I;
    else
      coeff[j] = 2.0f * (2.0f * fc) * sinf(phs) * I;
    /* por que? */
    /* h[j].re *= tmp * cos(phs); */
    /* h[j].im *= (tmp * sin(phs)); */
  }
  return (void *)coeff;
}
  
static void *lowpass_complex(float cutoff, float sr, int size, float complex *coeff) {
  void *e = check_complex(0.0f, cutoff, sr, size); if (e != NULL) return e;
  float fc = cutoff / sr;
  int midpoint = (size >> 01) | 01;

  for (int i = 1; i <= size; i++) {
    int j = i - 1, k = i - midpoint;
    if (i != midpoint)
      coeff[j] = ((sinf(two_pi * k * fc) / (pi * k)) * window_get(WINDOW_BLACKMAN_HARRIS, size, j));
    else
      coeff[j] = 2.0f * fc;
  }
  return (void *)coeff;
}

static void *highpass_complex(float cutoff, float sr, int size, float complex *coeff) {
  void *e = lowpass_complex(cutoff, sr, size, coeff); if (e != coeff) return e;
  return complement_complex(size, coeff);
}

#endif
