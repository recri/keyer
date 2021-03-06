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

#ifndef IQ_SWAP_H
#define IQ_SWAP_H

/*
** I/Q channel swap 
*/

#include "dspmath.h"

typedef struct {
} iq_swap_t;
typedef struct {
} iq_swap_options_t;

void iq_swap_configure(iq_swap_t *p, iq_swap_options_t *q) {
}

void *iq_swap_init(iq_swap_t *p, iq_swap_options_t *q) {
  return p;
}

void iq_swap_preconfigure(iq_swap_t *p, iq_swap_options_t *q) {
}

static float complex iq_swap_process(const float complex in) {
  return cimag(in) + creal(in) * I;
}
#endif
