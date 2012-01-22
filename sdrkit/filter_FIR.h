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
#ifndef FILTER_FIR_KERNEL_H
#define FILTER_FIR_KERNEL_H

#include "dmath.h"

/*
** construct the coefficients for a FIR filter
**
** taken from dttsp/src/filter.c
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
** Doxygen comments added by Dave Larsen, KV0S
**
** only the filters actually used are implemented,
** namely bandpass_complex and lowpass_real
*/

/*
** a lowpass real filter is used to implement polyphase spectra
*/
static float *lowpass_real(float cutoff, float sr, int size, float *coeff, float *window) {
  if ((cutoff < 0.0) || (cutoff > (sr / 2.0)))
    return "cutoff out of range";
  if (size < 1)
    return "size too small";
  if ((size & 1) == 0)
    return "size not odd";
  float *h = coeff;
  float *w = window;
  float fc = cutoff / sr;
  int midpoint = (size >> 01) | 01;
  // do this outside this call
  // (void) makewindow(BLACKMANHARRIS_WINDOW, size, w);
  for (int i = 1; i <= size; i++) {
    int j = i - 1;
    if (i != midpoint)
      h[j] = (sinf(twopi * (i - midpoint) * fc) / (pi * (i - midpoint))) * w[j];
    else
      h[midpoint - 1] = 2.0f * fc;
  }
  return coeff;
}

/*
** a complex bandpass filter is used to implement the radio bandpass
*/
static float _Complex *bandpass_complex(float lo, float hi, float sr, int size, float _Complex *coeff, float *window) {
  if ((lo < -(sr / 2.0)) || (hi > (sr / 2.0)) || (hi <= lo))
    return "lo frequency and/or hi frequency out of bounds";
  if (size < 1)
    return "size too small";
  if ((size&1) != 0)
    return "size not odd";

  float _Complex *h = coeff;
  float *w = window;
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
      tmp = (sinf(twopi * k * fc) / (pi * k)) * w[j];
    else
      tmp = 2.0f * fc;
    tmp *= 2.0f;
    h[j] = tmp * (cosf(phs) + I * sinf(phs));
  }
  return coeff;
}

#endif
