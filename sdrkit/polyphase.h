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
*/

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
