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
#ifndef POLYPHASE_H
#define POLYPHASE_H
/*
** Implement the polyphase spectrum pre-fft filtering
**
** Some notes.
**
** There was a discussion of polyphase fft at http://www.dsprelated.com/showmessage/45449/1.php
** Unfortunately, most of the links mentioned are dead.
**
** This is based on the dttsp-cgran-r624 sources.
**
** The implementation happens entirely in the fftw and in the choice of window function passed to it.
** A normal fft has a window the same size as the fft.  A polyphase fft has a window which is some
** integral multiple > 1 in size.
**
** The input samples to a fft are always convolved with the window, so
**    for i in 0 .. size-1
**	fft.input[i] = fft.input_sample[i] * fft.window[i]
** is what happens with a normal window.
**
** In a polyphase fft, we get:
**    for i in 0 .. size-1
**	fft.input[i] = fft.input_sample[i] * fft.window[i] + fft.input_sample[i+size] * fft.window[i+size]
** where the [i+size] gets replicated as often as necessary to consume the input samples and window.
**
** The window to a polyphase fft is a FIR low pass filter kernel.  It's referred to as the WOLAfir,
** for Weighted OverLap Add.
**
*/
#include "dspmath.h"
#include "filter_FIR.h"

static void *polyphase_fft_window(int polys, int size, float *coeff) {
  int fsize = polys*size;
  int adjust = (fsize&1)==0 ? -1 : 0;
  void *e = lowpass_real(1.0, size, fsize+adjust, WINDOW_BLACKMAN_HARRIS, coeff); if (e != coeff) return e;
  if (adjust != 0)
  coeff[fsize+adjust] = 0.0f;
  float maxTap = 0.0f;
  for (int i = 0; i < fsize+adjust; i += 1)
    maxTap = maxf(maxTap, coeff[i]);
  float normTap = 0.707107f/maxTap;
  for (int i = 0; i < polys*size-1; i += 1)
    coeff[i] *= normTap;
  return (void *)coeff;
}

#define COMPLEX_INTERLEAVED 1

#if COMPLEX_INTERLEAVED
static void polyphase_fft_convolve(int polys, int size, float *coeff, float complex *input, float complex *output) {
  for (int i = 0; i < size; i += 1)
    output[i] = *coeff++ * *input++;
  for (int j = 1; j < polys; j += 1)
    for (int i = 0; i < size; i += 1)
      output[i] += *coeff++ * *input++;
}
#else
static void polyphase_fft_convolve(int size, int polys, float *coeff, float *ireal, float *iimag, float *oreal, float *oimag) {
  for (int i = 0; i < size; i += 1) {
    oreal[i] = coeff[i] * ireal[i];
    oimag[i] = coeff[i] * iimag[i];
    for (int j = size; j < polys*size; j += size) {
      oreal[i] += coeff[j+i] * ireal[j+i];
      oimag[i] += coeff[j+i] * iimag[j+i];
    }
  }
}
#endif
#endif

#if 0
/*
** from dttsp-cgran-r624/src/spectrum.c
** Uses 8x fft size input samples
*/
  // where most recent signal started
  j = sb->fill;
    int k;
    for (i = 0; i < sb->size; i++) {
      out[i] = accum[j] * window[i];
      for (k = 1; k < 8; k++) {
	int accumidx = (j + k * sb->size) & sb->mask, winidx = i + k * sb->size;
	CXBreal(sb->timebuf, i) += CXBreal(sb->accum, accumidx) * sb->window[winidx];
	CXBimag(sb->timebuf, i) += CXBimag(sb->accum, accumidx) * sb->window[winidx];
      }
      j = ++j & sb->mask;
    }
/*
** from dttsp-cgran-r624/src/update.c
** sets up the 'window' for the polyphase
*/
      uni->spec.polyphase = TRUE;
      uni->spec.mask = (8 * uni->spec.size) - 1;
      {
	RealFIR WOLAfir;
	REAL MaxTap = 0;
	int i;
	WOLAfir = newFIR_Lowpass_REAL(1.0, (REAL) uni->spec.size, 8 * uni->spec.size - 1);
	memset(uni->spec.window, 0, 8 * sizeof(REAL) * uni->spec.size);
	memcpy(uni->spec.window, FIRcoef(WOLAfir), sizeof(REAL) * (8 * uni->spec.size - 1));
	for (i = 0; i < 8 * uni->spec.size; i++)
	  MaxTap = max(MaxTap, fabs(uni->spec.window[i]));
	MaxTap = 1.0f / MaxTap;
	for (i = 0; i < 8 * uni->spec.size; i++)
	  uni->spec.window[i] *= MaxTap;
	delFIR_REAL(WOLAfir);
      }
#endif
