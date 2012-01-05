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
#ifndef TIMING_H
#define TIMING_H

typedef struct {
  unsigned dit;
  unsigned dah;
  unsigned ies;
  unsigned ils;
  unsigned iws;
  unsigned rise;
  unsigned fall;
} timing_t;

static void keyer_timing_update(options_t *opts, timing_t *samples_per) {
  /* dit samples = (samples_per_second * second_per_minute) / (words_per_minute * dits_per_word)  */
  samples_per->dit = (unsigned) ((opts->sample_rate * 60) / (opts->wpm * opts->word));
  samples_per->dah = opts->dah * samples_per->dit;
  samples_per->ies = opts->ies * samples_per->dit;
  samples_per->ils = opts->ils * samples_per->dit;
  samples_per->iws = opts->iws * samples_per->dit;
  /* samples / ramp = samples_per_second * (millsecond_per_ramp / millisecond_per_second) */
  samples_per->rise = opts->sample_rate * (opts->rise / 1000);
  samples_per->fall = opts->sample_rate * (opts->fall / 1000);
}

#include <stdio.h>

static void keyer_timing_report(FILE *fp, options_t *opts, timing_t *samples_per) {
  fprintf(fp, "sample_rate = %u\n", opts->sample_rate);
  fprintf(fp, "word -> %f\n", opts->word);
  fprintf(fp, "wpm -> %f\n", opts->wpm);
  fprintf(fp, "samples_per dit -> %u\n", samples_per->dit);
  fprintf(fp, "dah -> %f\n", opts->dah);
  fprintf(fp, "samples_per dah -> %u\n", samples_per->dah);
  fprintf(fp, "ies -> %f\n", opts->ies);
  fprintf(fp, "samples_per ies -> %u\n", samples_per->ies);
  fprintf(fp, "ils -> %f\n", opts->ils);
  fprintf(fp, "samples_per ils -> %u\n", samples_per->ils);
  fprintf(fp, "iws -> %f\n", opts->iws);
  fprintf(fp, "samples_per iws -> %u\n", samples_per->iws);
  fprintf(fp, "fall -> %f\n", opts->fall);
  fprintf(fp, "samples_per fall -> %u\n", samples_per->fall);
  fprintf(fp, "rise -> %f\n", opts->rise);
  fprintf(fp, "samples_per rise -> %u\n", samples_per->rise);
}

#endif
