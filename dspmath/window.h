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
#ifndef WINDOW_H
#define WINDOW_H

/*
  window.h - generate windowing functions for ffts and filters.
  This file is stolen from dttsp, see comments further down
  Augmented from http://en.wikipedia.org/wiki/Window_function
  as of 2012-06-09.
*/

#include "dspmath.h"
#if 0
#include <gsl/gsl_sf_bessel.h>
#endif

typedef enum {
  WINDOW_NONE = -1,
  WINDOW_RECTANGULAR = 0, 
  WINDOW_HANN = 1,		/* "Hanning" */
  WINDOW_WELCH = 2,
  WINDOW_PARZEN = 3,
  WINDOW_BARTLETT = 4,
  WINDOW_HAMMING = 5,
  WINDOW_BLACKMAN2 = 6,
  WINDOW_BLACKMAN3 = 7,
  WINDOW_BLACKMAN4 = 8,
  WINDOW_EXPONENTIAL = 9,
  WINDOW_RIEMANN = 10,
  WINDOW_BLACKMAN_HARRIS = 11,
  WINDOW_BLACKMAN_NUTTALL = 12,
  WINDOW_NUTTALL = 13,
  WINDOW_FLAT_TOP = 14,
  WINDOW_TUKEY = 15,
  WINDOW_COSINE = 16,
  WINDOW_LANCZOS = 17,
  WINDOW_TRIANGULAR = 18,
  WINDOW_GAUSSIAN = 19,
  WINDOW_BARTLETT_HANN = 20,
  WINDOW_KAISER = 21,
  WINDOW_BLACKMAN = 22,
  WINDOW_EXPONENTIAL_30 = 23,
  WINDOW_EXPONENTIAL_60 = 24,
  WINDOW_EXPONENTIAL_90 = 25,
  WINDOW_GAUSSIAN_10 = 26,
  WINDOW_GAUSSIAN_25 = 27
} window_type_t;

#ifdef FRAMEWORK_H
/* these can be listed in any order */
/* unimplemented windows are commented out */
static fw_option_custom_t window_mode_custom_option[] = {
  { "none", WINDOW_NONE },
  { "rectangular", WINDOW_RECTANGULAR },
  { "hann", WINDOW_HANN },
  { "welch", WINDOW_WELCH },
  { "parzen", WINDOW_PARZEN },
  { "bartlett", WINDOW_BARTLETT },
  { "hamming", WINDOW_HAMMING },
  { "blackman", WINDOW_BLACKMAN },
  { "blackman2", WINDOW_BLACKMAN2 },
  { "blackman3", WINDOW_BLACKMAN3 },
  { "blackman4", WINDOW_BLACKMAN4 },
  { "exponential", WINDOW_EXPONENTIAL },
  { "exponential-30", WINDOW_EXPONENTIAL_30 },
  { "exponential-60", WINDOW_EXPONENTIAL_60 },
  { "exponential-90", WINDOW_EXPONENTIAL_90 },
  { "riemann", WINDOW_RIEMANN },
  { "blackman-harris", WINDOW_BLACKMAN_HARRIS },
  { "blackman-nuttall", WINDOW_BLACKMAN_NUTTALL },
  { "nuttall", WINDOW_NUTTALL },
  { "flat-top", WINDOW_FLAT_TOP },
  { "cosine", WINDOW_COSINE },
  { "lanczos", WINDOW_LANCZOS },
  { "triangular", WINDOW_TRIANGULAR },
  { "gaussian", WINDOW_GAUSSIAN },
  { "gaussian-10", WINDOW_GAUSSIAN_10 },
  { "gaussian-25", WINDOW_GAUSSIAN_25 },
  { "bartlett-hann", WINDOW_BARTLETT_HANN },
  /*  { "tukey", WINDOW_TUKEY }, */
  /*  { "kaiser", WINDOW_KAISER }, */
  { NULL, -1 }
};
#endif

/** 
* @file window.c
* @brief Functions to allow windowing on the signal 
* @author Frank Brickle, AB2KT and Bob McGwier, N4HY 

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2006,2007 by Frank Brickle, AB2KT and Bob McGwier, N4HY
Implemented from code by Bill Schottstaedt of Snd Editor at CCRMA
Doxygen comments added by Dave Larsen, KV0S

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 7 of the License, or
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

/** shamelessly stolen from Bill Schottstaedt's clm.c 
* made worse in the process, but enough for our purposes here 
*/


/** mostly taken from
 *    Fredric J. Harris, "On the Use of Windows for Harmonic Analysis with the
 *    Discrete Fourier Transform," Proceedings of the IEEE, Vol. 66, No. 1,
 *    January 1978.
 *    Albert H. Nuttall, "Some Windows with Very Good Sidelobe Behaviour", 
 *    IEEE Transactions of Acoustics, Speech, and Signal Processing, Vol. ASSP-29,
 *    No. 1, February 1981, pp 84-91
 *
 * JOS had slightly different numbers for the Blackman-Harris windows.
 */

/* -------------------------------------------------------------------------- */
/** @brief Function to make the window 
* 
* @param type -- uses window_types_t 
* @param size -- size of window 
* @param window -- data 
* @return void
*/
/* ---------------------------------------------------------------------------- */
static float cosine_series1(const int size, const int k, const double a0, const double a1) {
  return a0 - a1 * cos((dtwo_pi * k) / (size-1));
}    
static float cosine_series2(const int size, const int k, const double a0, const double a1, const double a2) {
  return cosine_series1(size, k, a0, a1) + a2 * cos((2 * dtwo_pi * k) / (size-1));
}
static float cosine_series3(const int size, const int k, const double a0, const double a1, const double a2, const double a3) {
  return cosine_series2(size, k, a0, a1, a2) - a3 * cos((3 * dtwo_pi * k) / (size-1));
}
static float cosine_series4(const int size, const int k, const double a0, const double a1, const double a2, const double a3, const double a4) {
  return cosine_series3(size, k, a0, a1, a2, a3) + a4 * cos((4 * dtwo_pi * k) / (size-1));
}
static float gaussian(const int size, const int k, const double sigma) {
  return exp(-0.5 * square((k - (size-1) / 2.0) / (sigma * (size-1) / 2.0)));
}
static float exponential(const int size, const int k, const double decay) {
  double tau = (size / 2.0) * (8.69 / decay); /* for decay over half window of decay decibels */
  return exp(-fabs(k-(size-1)/2.0)/tau);
}
static float sinc(const float x) { // sinc(x) = sin(pi x) / (pi x), sinc(0) == 1
  return x == 0 ? 1 : sin(x * pi) / (x * pi);
}
static float window_get(const window_type_t type, const int size, int k) {
  /* apply symmetry up front */
  if (k > (size>>1)) k = (size-1)-k;
  /* compute the type */
  switch (type) {
  case WINDOW_RECTANGULAR: return 1.0;
  case WINDOW_TRIANGULAR: return 1.0 - fabs( (k - ((size-1)/2.0)) / (size/2.0) );
  case WINDOW_BARTLETT: return 1.0 - fabs( (k - ((size-1)/2.0)) / ((size-1)/2.0) );
  case WINDOW_BARTLETT_HANN: return 0.62 - 0.48 * fabs((double)k/(size-1)-0.5) -0.38 * cos(k * dtwo_pi / (size-1));
  case WINDOW_WELCH: return 1.0 - sqr( (k - ((size-1)/2.0)) / ((size-1)/2.0) );
  case WINDOW_PARZEN: {
    // the wikipedia definition runs from -N/2 to N/2, so 0 == -N/2
    k -= (size>>1);
    return (fabs(k) <= size/4.0) ? 
      1.0 - 6.0*sqr(k/(size/2.0)) * (1-fabs(k)/(size/2.0)) :
      2.0  * cube(1.0 - fabs(k) / (size/2.0) );
  }
  case WINDOW_HANN:  return cosine_series1(size, k, 0.50, 0.50);    /* "Hanning" */
  case WINDOW_HAMMING:  return cosine_series1(size, k, 0.54, 0.46);
  case WINDOW_BLACKMAN: return cosine_series2(size, k, 0.42, 0.50, 0.08); /* per wikipedia */
  case WINDOW_BLACKMAN2: /* using Chebyshev polynomial equivalents here */
    return .34401 + (cos(k * dtwo_pi / size) * 
		     (-.49755 + (cos(k * dtwo_pi / size) * .15844)));
  case WINDOW_BLACKMAN3:
    return .21747 + (cos(k * dtwo_pi / size) * 
		     (-.45325 + (cos(k * dtwo_pi / size) * 
				 (.28256 - (cos(k * dtwo_pi / size) * .04672)))));
  case WINDOW_BLACKMAN4:
    return .084037 + (cos(k * dtwo_pi / size) * 
		      (-.29145 + (cos(k * dtwo_pi / size) * 
				  (.375696 + (cos(k * dtwo_pi / size) * 
					      (-.20762 + (cos(k * dtwo_pi / size) * .041194)))))));
  case WINDOW_EXPONENTIAL:      return exponential(size, k, 10); /* decays 10 dB over half window */
  case WINDOW_EXPONENTIAL_30:   return exponential(size, k, 30); /* decays 30 dB over half window */
  case WINDOW_EXPONENTIAL_60:   return exponential(size, k, 60); /* decays 60 dB over half window */
  case WINDOW_EXPONENTIAL_90:   return exponential(size, k, 90); /* decays 90 dB over half window */
  case WINDOW_BLACKMAN_HARRIS:  return cosine_series3(size, k, 0.3587500, 0.4882900, 0.1412800, 0.0116800);
  case WINDOW_BLACKMAN_NUTTALL: return cosine_series3(size, k, 0.3635819, 0.4891775, 0.1365995, 0.0106411);
  case WINDOW_NUTTALL:          return cosine_series3(size, k, 0.3557680, 0.4873960, 0.1442320, 0.0126040);
  case WINDOW_FLAT_TOP:         return cosine_series4(size, k, 1.0000000, 1.9300000, 1.2900000, 0.3880000, 0.032);
     // also known as the sine window
  case WINDOW_COSINE:           return sin(pi*k / (size-1));

  case WINDOW_GAUSSIAN:         return gaussian(size, k, 0.50);
  case WINDOW_GAUSSIAN_25:      return gaussian(size, k, 0.25);
  case WINDOW_GAUSSIAN_10:	return gaussian(size, k, 0.10);

    // Tukey window is an interpolation between a Hann and a rectangular window
    // parameterized by alpha, somewhat like a raised cosine keyed tone
  case WINDOW_TUKEY:            return 0;
  case WINDOW_KAISER: {
#if 0
    // I_0(pi alpha sqrt(1 - square(2 k / (size-1)))) / I_0(pi alpha), alpha typically 3
    const float alpha = 3;
    return gsl_sf_bessel_I0(pi * alpha * sqrt(1 - square(2.0 * k / (size-1)))) / gsl_sf_bessel_I0(pi * alpha);
#else
    return 0;
#endif
  }
  case WINDOW_RIEMANN: {
    const int midn = size >> 1;
    if (midn == k) return 1.0;
    if (k > midn) k = size-1 - k;
    const double cx = (midn - k) * dtwo_pi / size;
    return sin(cx) / cx;
  }
  case WINDOW_LANCZOS:          return sinc(2.0*k/(size-1) - 1.0);
  default:			return 0.0;
  }
}
static float window_get2(const window_type_t type1, const window_type_t type2, const int size, int k) {
  float val = 0;
  if (type1 != WINDOW_NONE) {
    val = window_get(type1, size, k);
    if (type2 != WINDOW_NONE) {
      val *= window_get(type2, size, k);
    }
  }
  return val;
}
static void window_make2(const window_type_t type1, const window_type_t type2, const int size, float *window) {
  if (type1 == WINDOW_NONE)
    for (int i = 0; i < size; i++) window[i] = 0;
  else if (type2 == WINDOW_NONE)
    for (int i = 0; i < size; i++) window[i] = window_get(type1, size, i);
  else
    for (int i = 0; i < size; i++) window[i] = window_get(type1, size, i) * window_get(type2, size, i);
}
static void window_make(const window_type_t type, const int size, float *window) {
  return window_make2(type, WINDOW_NONE, size, window);
}
#endif
