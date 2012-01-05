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
#ifndef OPTIONS_TONE_H
#define OPTIONS_TONE_H
  { "freq", "frequency of tone in hertz", "700.0", options_handle_freq, option_float, offsetof(options_t, freq) },
  { "gain", "level of tone in decibels", "-30.0", options_handle_gain, option_float, offsetof(options_t, gain) },
  { "rise", "rise time in milliseconds", "5.0", options_handle_rise, option_float, offsetof(options_t, rise) },
  { "fall", "fall time in milliseconds", "5.0", options_handle_fall, option_float, offsetof(options_t, fall) },
#endif
