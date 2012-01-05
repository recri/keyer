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
#ifndef OPTONS_KEYER_H
#define OPTONS_KEYER_H
  { "swap", "swap the dit and dah paddles", "0", options_handle_swap, option_bool, offsetof(options_t, swap) },
  { "alsp", "auto letter spacing", "0", options_handle_alsp, option_bool, offsetof(options_t, alsp) },
  { "awsp", "auto word spacing", "0", options_handle_awsp, option_bool, offsetof(options_t, awsp) },
  { "mode", "iambic keyer mode", "A", options_handle_mode, option_char, offsetof(options_t, mode) },
#endif
