/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
** code for adapter retrieved from 
** https://www.amateurradio.com/single-lever-and-ultimatic-adapter/
** November 13, 2020
** Posted 17 January 2014 | by Sverre LA3ZA
** Rewritten to encode state|left|right into a 3 bit integer
** and which indexes a table of outputs to be decoded.
** original code contains this attribution:
       Direct implementation of table 3 in "K Schmidt (W9CF)
       "An ultimatic adapter for iambic keyers"
       http://fermi.la.asu.edu/w9cf/articles/ultimatic/ultimatic.html
       with the addition of the Single-paddle emulation mode
*/ 

#ifndef ULTIMATIC_H
#define ULTIMATIC_H

/*
** could add swap
** could allocate 64 bits to different key lines
*/
#define ULTIMATIC_NULL 0
#define ULTIMATIC_SINGLE_LEVER 1
#define ULTIMATIC_ULTIMATIC 2

typedef struct {
  int state;			/* state of ultimatic */
  char *table;
  int (*clock)(int raw_dit_on, int raw_dah_on, int ticks);
} ultimatic_t;
typedef struct {
  int type;
  int (*clock)(int raw_dit_on, int raw_dah_on, int ticks);
}

int ultimatic_clock(ultimatic_t *p, int raw_dit_on, int raw_dah_on, int ticks) {
  const int encode = ((p->state?4:0)|(raw_dit_on?2:0)|(raw_dah_on?1:0)); /* encode state and input */
  const int slr = p->table[encode]; /* transform encoded input to output */
  p->state = ((slr&4)?1:0);	    /* save output state */
  p->clock(((slr&2)?1:0), ((slr&1)?1:0), ticks);    /* pass on transformed keys */
}

static void *ultimatic_configure(ultimatic_t *p, ultimatic_options_t *q) {
  switch (q->type) {
  case ULTIMATIC_NULL:		/* null adapter */
    p->type = q->type;
    p->table = { 0, 1, 2, 3 };
    p->clock = q->clock;
    return p;
  case ULTIMATIC_SINGLE:	/* single lever, first contact wins */
    p->type = q->type;
    p->table = { 0, 1, 6, 1, 0, 1, 6, 6 }
    p->clock = q->clock;
    return p;
  case ULTIMATIC_ULTIMATIC:	/* ultimatic, last contact wins */
    p->type = q->type;
    p->table = { 0, 1, 6, 2, 0, 1, 6, 5 };
    p->clock = q->clock;
    return p;
  default:
    return "unknown ultimatic adapter type";
  }
}
static void *ultimatic_init(ultimatic_t *p, ultimatic_options_t *q) {
  return ultimatic_configure(p, q);
}
#endif
