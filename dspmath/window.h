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

typedef enum {
  WINDOW_RECTANGULAR = 0, 
  WINDOW_HANNING = 1,		/* Hann */
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
  WINDOW_KAISER = 21
} window_type_t;

static char *window_names[] = {
  "rectangular", 
  "hanning",
  "welch",
  "parzen",
  "bartlett",
  "hamming",
  "blackman2",
  "blackman3",
  "blackman4",
  "exponential",
  "riemann",
  "blackman-harris",
  "blackman-nuttall",
  "nuttall",
  "flat-top",
  "tukey",
  "cosine",
  "lanczos",
  "triangular",
  "gaussian",
  "bartlett-hann",
  "kaiser",
  NULL
};

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
static float window_get(const window_type_t type, const int size, int k) {
  switch (type) {
  case WINDOW_RECTANGULAR: return 1.0;
  case WINDOW_HANNING: {	/* Hann would be more accurate */
    const int midn = size >> 1;
    if (k > midn) k = (size-1) - k;
    return 0.5 - 0.5 * cos(k * dtwo_pi / (size-1));
  }
  case WINDOW_WELCH: {
    const int midn = size >> 1;
    const int midm1 = (size - 1) / 2;
    const int midp1 = (size + 1) / 2;
    if (k > midn) k = size-1 - k;
    return 1.0 - sqr( (k - midm1) / (double) midp1);
  }
  case WINDOW_PARZEN: {
    const int midn = size >> 1;
    const int midm1 = (size - 1) / 2;
    const int midp1 = (size + 1) / 2;
    if (k > midn) k = size-1 - k;
    return 1.0 - fabs( (k - midm1) / (double) midp1);
  }
  case WINDOW_BARTLETT: {
    const int midn = size >> 1;
    if (k > midn) k = size-1 - k;
    return k / (double)midn;
  }
  case WINDOW_HAMMING: {
    const int midn = size >> 1;
    if (k > midn) k = size-1 - k;
    return 0.54 - 0.46 * cos(k * dtwo_pi / (size-1));
  }
  case WINDOW_BLACKMAN2: {	/* using Chebyshev polynomial equivalents here */
    const int midn = size >> 1;
    if (k > midn) k = size-1 - k;
    double cx = cos(k * dtwo_pi / size);
    return .34401 + (cx * (-.49755 + (cx * .15844)));
  }
  case WINDOW_BLACKMAN3: {
    const int midn = size >> 1;
    if (k > midn) k = size-1 - k;
    double cx = cos(k * dtwo_pi / size);
    return .21747 + (cx * (-.45325 + (cx * (.28256 - (cx * .04672)))));
  }
  case WINDOW_BLACKMAN4: {
    const int midn = size >> 1;
    if (k > midn) k = size-1 - k;
    double cx = cos(k * dtwo_pi / size);
    return .084037 + (cx * (-.29145 + (cx * (.375696 + (cx * (-.20762 + (cx * .041194)))))));
  }
  case WINDOW_EXPONENTIAL: {
    const int midn = size >> 1;
    const double expn = log(2.0) / midn + 1.0;
    double expsum = 1.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--) {
      if (i == k || j == k)
	return expsum - 1.0;
      expsum *= expn;
    }
    break;
  }
  case WINDOW_RIEMANN: {
    const int midn = size >> 1;
    if (midn == k) return 1.0;
    if (k > midn) k = size-1 - k;
    const double cx = (midn - k) * dtwo_pi / size;
    return sin(cx) / cx;
  }
  case WINDOW_BLACKMAN_HARRIS: {
    // corrected per wikipedia
    const double a0 = 0.35875, a1 = 0.48829, a2 = 0.14128, a3 = 0.01168;
    const double arg = k * dtwo_pi / (size - 1);
    return a0 - a1 * cos(arg) + a2 * cos(2 * arg) - a3 * cos(3 * arg);
  }
  case WINDOW_BLACKMAN_NUTTALL: {
    // corrected and renamed per wikipedia
    const double a0 = 0.3635819, a1 = 0.4891775, a2 = 0.1365995, a3 = 0.0106411;
    const double arg = k * dtwo_pi / (size - 1);
    return a0 - a1 * cos(arg) + a2 * cos(2 * arg) - a3 * cos(3 * arg);
  }
  case WINDOW_NUTTALL: {
    // wikipedia's version
    const double a0 = 0.355768, a1 = 0.487396, a2 = 0.144232, a3 = 0.012604;
    const double arg = k * dtwo_pi / (size - 1);
    return a0 - a1 * cos(arg) + a2 * cos(2 * arg) - a3 * cos(3 * arg);
  }
  case WINDOW_FLAT_TOP: {
    const double a0 = 1.0, a1 = 1.93, a2 = 1.29, a3 = 0.388, a4 = 0.032;
    const double arg = k * dtwo_pi / (size - 1);
    return a0 - a1 * cos(arg) + a2 * cos(2 * arg) - a3 * cos(3 * arg) + a4 * cos(4 * arg);

  }
  case WINDOW_TUKEY: {
    // Tukey window is an interpolation between a Hann and a rectangular window
    // parameterized by alpha, somewhat like a raised cosine keyed tone
    return 0;
  }
  case WINDOW_COSINE: {
    // also known as the sine window
    return sin(pi*k / (size-1));
  }
  case WINDOW_LANCZOS: {
    return 0;// sinc(2*k/(size-1)), normalized sinc(x) = sin(pi x) / (pi x), sinc(0) == 1
  }
  case WINDOW_TRIANGULAR: {
    return 2.0 / (size+1) * ((size+1)/2.0 - fabs(k-(size-1)/2.0));
  }
  case WINDOW_GAUSSIAN: {
    // gaussian parameterized by sigma <= 0.5
    const double sigma = 0.5;
    return exp(-0.5 * pow((k - (size-1) / 2.0) / (sigma * (size-1) / 2.0), 2));
  }
  case WINDOW_BARTLETT_HANN: {
    return 0;
  }
  case WINDOW_KAISER: {
    return 0;
  }
  }
  return 1.0 / 0.0;
}
static void window_make(const window_type_t type, const int size, float *window) {
  for (int i = 0; i < size; i++)
    window[i] = window_get(type, size, i);
}
#endif
