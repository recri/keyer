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

#include <string.h>
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

static const float pi = 3.14159265358979323846f;		/* pi */
static const float half_pi = 1.57079632679489661923f;		/* pi/2 */
static const float quarter_pi = 0.78539816339744830962f;	/* pi/4 */
static const float two_pi = 2*3.14159265358979323846f;		/* 2*pi */

static const double dpi = 3.14159265358979323846;		/* pi */
static const double dhalf_pi = 1.57079632679489661923;		/* pi/2 */
static const double dquarter_pi = 0.78539816339744830962;	/* pi/4 */
static const double dtwo_pi = 2*3.14159265358979323846;		/* 2*pi */

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

static double sqr(double x) { return (x * x); }

// round log2(n) up to integer
static int npoof2(int n) { int i; for (i = 0, n -= 1; n > 0; i += 1, n >>= 1); return i; }
// exp2(log2(n)) rounded up to a block.
static int nblock2(int n) { return 1 << npoof2(n); }

/*
** these are banal
*/
static float minf(float a, float b) { return a < b ? a : b; }
static float maxf(float a, float b) { return a > b ? a : b; }
static float squaref(float x) { return x * x; }

static double square(double x) { return x * x; }

/*
** these are functions you learn to use in computer graphics
*/
/* clamp a value between extremes */
static float clampf(float a, float a_min, float a_max) {
  return minf(maxf(a, a_min), a_max);
}

/* linearly interpolate between two extremes, and beyond */
static float interpf(float p, float v0, float v1) {
  return (1.0f-p)*v0 + p*v1;
}

/* convert a dB gain to a linear voltage gain */
static float dB_to_linear(float dBgain) {
  return powf(10.0f, dBgain / 20.0f);
}

/* complex multiply two complex vectors together */ 
static void complex_vector_multiply(float complex *dst, float complex *src1, float complex *src2, int n) {
  while (--n >= 0) *dst++ = *src1++ * *src2++;
}

/* multiply a complex vector by a real scale */
static void complex_vector_scale(float complex *dst, float complex *src, float scale, int n) {
  while (--n >= 0) *dst++ = *src++ * scale;
}

/* copy a complex vector */
static void complex_vector_copy(float complex *dst, float complex *src, int n) {
  memcpy(dst, src, n*sizeof(float complex));
}

/* clear a complex vector */
static void complex_vector_clear(float complex *dst, int n) {
  memset(dst, 0, n*sizeof(float complex));
}

static float complex_vector_max_abs(float complex *dst, int n) {
  float max_abs = 0.0f;
  while (--n >= 0) max_abs = maxf(max_abs, cabsf(*dst++));
  return max_abs;
}

static float complex_vector_normalize(float complex *dst, float complex *src, int n) {
  float max_abs = complex_vector_max_abs(src, n);
  if (max_abs > 0.0f) complex_vector_scale(dst, src, 1.0f/max_abs, n);
  return max_abs;
}

#endif

