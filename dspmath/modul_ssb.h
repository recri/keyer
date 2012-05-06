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

#ifndef MODUL_SSB_H
#define MODUL_SSB_H

/*
** modulation for any single sideband mode - rewritten from dttsp
** doesn't do much, just compensates for the discarded sideband power
** Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
*/

#include "dspmath.h"

typedef struct {
} modul_ssb_t;

typedef struct {
} modul_ssb_options_t;

static void modul_ssb_configure(modul_ssb_t *p, modul_ssb_options_t *q) {
}

static void *modul_ssb_preconfigure(modul_ssb_t *p, modul_ssb_options_t *q) {
  return p;
}

static void *modul_ssb_init(modul_ssb_t *p, modul_ssb_options_t *q) {
  void *e = modul_ssb_preconfigure(p,q); if (e != p) return e;
  modul_ssb_configure(p, q);
  return p;
}

static complex float modul_ssb_process(modul_ssb_t *p, const float complex in) {
  return 2.0f * in;
}

#endif
