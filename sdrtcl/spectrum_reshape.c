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

/*
*/

#define FRAMEWORK_USES_JACK 0
#define FRAMEWORK_USES_COMMAND 1
#define FRAMEWORK_USES_OPTIONS 1
#define FRAMEWORK_USES_SUBCOMMANDS 1

#include "../dspmath/dspmath.h"
#include "framework.h"

/*
** reshape spectrum.
** change the size of the spectrum.
** rotate by an lo offset.
** change ordering of bins.
** apply filters.
** maintain decayed average.
**
** it seems that the ordering is only relevant when you hand the spectrum
** to an fft for conversion back to time domain, the coefficients form
** a discrete set of points on the circle whether they're ordered from
** min or 0.
**
** The natural ordering used by fftw starts from DC, f=0, increases to
** f=max, steps to f=min, and finishes at the maximum negative frequency.
** A rotation of N/2, where N is the number of frequency bins, is equivalent
** to reordering to start from f=min and ending with f=max
**
** According to browsing around filter banks, which implement multiple channel
** extraction from a sample stream, directly reshaping the spectrum like this
** is not computationally efficient when multiple results are required.  The
** basic idea is right -- ie convolve the band pass filter for the desired band,
** rotate the desired band to base band, reduce the number of coefficients to
** the desired output bandwidth -- but the brute force composition of the
** operations is not the best way to organize the computation.
*/
