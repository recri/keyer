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
#ifndef DMATH_H
#define DMATH_H

#include <complex.h>
#include <math.h>


/*
** this comes from http://faust.grame.fr/
*/

// On Intel set FZ (Flush to Zero) and DAZ (Denormals Are Zero)
// flags to avoid costly denormals
#ifdef __SSE__
    #include <xmmintrin.h>
    #ifdef __SSE2__
        #define AVOID_DENORMALS _mm_setcsr(_mm_getcsr() | 0x8040)
    #else
        #define AVOID_DENORMALS _mm_setcsr(_mm_getcsr() | 0x8000)
    #endif
#else
    #define AVOID_DENORMALS 
#endif


static float squaref(float x) { return x * x; }

static const float pi = 3.14159265358979323846f;		/* pi */
static const float half_pi = 1.57079632679489661923f;		/* pi/2 */
static const float quarter_pi = 0.78539816339744830962f;	/* pi/4 */
static const float two_pi = 2*3.14159265358979323846f;		/* 2*pi */

/*
** these functions are from dttsp/banal.h
*/
#define MONDO 1e16
#define BITSY 1e-16
#define KINDA 2.56e2

static float sqrf(float x) { return (x * x); }
static float Log10(float x) { return log10(x + BITSY); }
static float Log10P(float x) { return +10.0 * log10(x + BITSY); }
static float Log10Q(float x) { return -10.0 * log10(x + BITSY); }
static float dBP(float x) { return 20.0 * log10(x + BITSY); }
static float DamPlus(float x0, float x1) { return 0.9995 * x0 + 0.0005 * x1; }

#endif

