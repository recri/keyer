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
#ifndef SDRKIT_WINDOW_H
#define SDRKIT_WINDOW_H

/*
  sdrkit_window.h - generate windowing functions for ffts and filters.

  This file is stolen from dttsp, see comments further down
*/

#include <math.h>
#include "sdrkit_math.h"

typedef enum {
  WINDOW_RECTANGULAR,
  WINDOW_HANNING,
  WINDOW_WELCH,
  WINDOW_PARZEN,
  WINDOW_BARTLETT,
  WINDOW_HAMMING,
  WINDOW_BLACKMAN2,
  WINDOW_BLACKMAN3,
  WINDOW_BLACKMAN4,
  WINDOW_EXPONENTIAL,
  WINDOW_RIEMANN,
  WINDOW_BLACKMANHARRIS,
  WINDOW_NUTTALL,
} window_type_t;

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
static void window_make(const window_type_t type, const int size, float *window) {
  switch (type) {
  case WINDOW_RECTANGULAR: {
    for (int i = 0; i < size; i++)
      window[i] = 1.0;
    break;
  }
  case WINDOW_HANNING: {	/* Hann would be more accurate */
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float freq = two_pi / size;
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += freq)
      window[j] = (window[i] = (float) (0.5 - 0.5 * cos(angle)));
    break;
  }
  case WINDOW_WELCH: {
    const int midn = size >> 1;
    const int midm1 = (size - 1) / 2;
    const int midp1 = (size + 1) / 2;
    for (int i = 0, j = size - 1; i <= midn; i++, j--)
      window[j] =
	(window[i] = (float) (1.0 - sqrf((float) (i - midm1) / (float) midp1)));
    break;
  }
  case WINDOW_PARZEN: {
    const int midn = size >> 1;
    const int midm1 = (size - 1) / 2;
    const int midp1 = (size + 1) / 2;
    for (int i = 0, j = size - 1; i <= midn; i++, j--)
      window[j] = (window[i] = (float) (1.0 - fabs((float) (i - midm1) / (float) midp1)));
    break;
  }
  case WINDOW_BARTLETT: {
    const int midn = size >> 1;
    const float rate = (float) (1.0 / (float) midn);
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += rate)
      window[j] = (window[i] = angle);
    break;
  }
  case WINDOW_HAMMING: {
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float freq = two_pi / (float) size;
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += freq)
      window[j] = (window[i] = (float) (0.54 - 0.46 * cos(angle)));
    break;
  }
  case WINDOW_BLACKMAN2: {	/* using Chebyshev polynomial equivalents here */
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float freq = two_pi / (float) size;
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += freq) {
      float cx = (float) cos(angle);
      window[j] = window[i] = (.34401 + (cx * (-.49755 + (cx * .15844))));
    }
    break;
  }
  case WINDOW_BLACKMAN3: {
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float freq = two_pi / (float) size;
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += freq) {
      float cx = (float) cos(angle);
      window[j] = window[i] = (float)
	(.21747 +
	 (cx *
	  (-.45325 + (cx * (.28256 - (cx * .04672))))));
    }
    break;
  }
  case WINDOW_BLACKMAN4: {
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float freq = two_pi / (float) size;
    float angle = 0.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--, angle += freq) {
      float cx = (float) cos(angle);
      window[j] = (window[i] = (float)
		   (.084037 +
		    (cx *
		     (-.29145 +
		      (cx *
		       (.375696 + (cx * (-.20762 + (cx * .041194)))))))));
    }
    break;
  }
  case WINDOW_EXPONENTIAL: {
    const int midn = size >> 1;
    const float expn = (float) (log(2.0) / (float) midn + 1.0);
    float expsum = 1.0;
    for (int i = 0, j = size - 1; i <= midn; i++, j--) {
      window[j] = (window[i] = (float) (expsum - 1.0));
      expsum *= expn;
    }
    break;
  }
  case WINDOW_RIEMANN: {
    const int midn = size >> 1;
    const float two_pi = 2 * M_PI;
    const float sr1 = two_pi / (float) size;
    for (int i = 0, j = size - 1; i <= midn; i++, j--) {
      if (i == midn)
	window[j] = (window[i] = 1.0);
      else {
	/* split out because NeXT C compiler can't handle the full expression */
	float cx = sr1 * (midn - i);
	window[i] = (float) (sin(cx) / cx);
	window[j] = window[i];
      }
    }
    break;
  }
  case WINDOW_BLACKMANHARRIS: {
    const float two_pi = 2 * M_PI;
    const float a0 = 0.35875f, a1 = 0.48829f, a2 = 0.14128f, a3 = 0.01168f;
    for (int i = 0; i < size; i++) {
      window[i] =
	(float) (a0 -
		 a1 * cos(two_pi * (float) (i + 0.5) /
			  (float) (size - 1)) +
		 a2 * cos(2.0 * two_pi * (float) (i + 0.5) /
			  (float) (size - 1)) -
		 a3 * cos(3.0 * two_pi * (float) (i + 0.5) /
			  (float) (size - 1)));
    }
    break;
  }
  case WINDOW_NUTTALL: {
    const float two_pi = 2 * M_PI;
    const float a0 = 0.3635819f, a1 = 0.4891775f, a2 = 0.1365995f, a3 = 0.0106411f;

    for (int i = 0; i < size; i++) {
	window[i] =
	  (float) (a0 -
		  a1 * cos(two_pi * (float) (i + 0.5) /
			   (float) (size - 1)) +
		  a2 * cos(2.0 * two_pi * (float) (i + 0.5) /
			   (float) (size - 1)) -
		  a3 * cos(3.0 * two_pi * (float) (i + 0.5) /
			   (float) (size - 1)));
      }
      break;
  }
  }
}
#endif
