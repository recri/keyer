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
#ifndef OPTIONS_TIMING_H
#define OPTIONS_TIMING_H
  { "word", "dits in a word", "50.0", options_handle_word, option_float, offsetof(options_t, word) },
  { "wpm", "words per minute", "18.0", options_handle_wpm, option_float, offsetof(options_t, wpm) },
  { "dah", "dah length in dits", "3.0", options_handle_dah, option_float, offsetof(options_t, dah) },
  { "ies", "inter-element space in dits", "1.0", options_handle_ies, option_float, offsetof(options_t, ies) },
  { "ils", "inter-letter space in dits", "3.0", options_handle_ils, option_float, offsetof(options_t, ils) },
  { "iws", "inter-word space in dits", "7.0", options_handle_iws, option_float, offsetof(options_t, iws) },
#endif
