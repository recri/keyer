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
#ifndef MORSE_TIMING_H
#define MORSE_TIMING_H

typedef struct {
  unsigned base;		/* base dit clock */
  unsigned dit;
  unsigned dah;
  unsigned ies;
  unsigned ils;
  unsigned iws;
  unsigned rise;
  unsigned fall;
} morse_timing_t;

static void morse_timing(morse_timing_t *samples_per, unsigned sample_rate, float word, float wpm, 
			 float dit, float dah, float ies, float ils, float iws,
			 float weight, float ratio, float comp) {
  /* ms_per_dit = (ms_per_second * second_per_minute) / (words_per_minute * dits_per_word */
  float ms_per_dit = (1000 * 60) / (wpm * word);
  float r = (ratio-50)/100.0;
  float w = (weight-50)/100.0;
  float c = comp / ms_per_dit; /* ms / ms_per_dit */
  /* samples_per_dit = (samples_per_second * second_per_minute) / (words_per_minute * dits_per_word)  */
  samples_per->base = (unsigned) ((sample_rate * 60) / (wpm * word));
  samples_per->dit = (dit+r+w-c) * samples_per->base;
  samples_per->dah = (dah-r+w-c) * samples_per->base;
  samples_per->ies = (ies  -w+c) * samples_per->base;
  samples_per->ils = (ils  -w+c) * samples_per->base;
  samples_per->iws = (iws  -w+c) * samples_per->base;
}
#endif
