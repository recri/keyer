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
#ifndef OPTIONS_COMMON_H
#define OPTIONS_COMMON_H
  { "verbose", "amount of diagnostic output", "0", options_handle_verbose, option_int, offsetof(options_t, verbose) },

  { "chan", "midi channel used for keyer", "1", options_handle_chan, option_int, offsetof(options_t, chan) },
  { "note", "base midi note used for keyer", "0", options_handle_note, option_int, offsetof(options_t, note) },

  { "server", "jack server name", "default", options_handle_server, option_string, offsetof(options_t, server) },
  { "client", "jack client name", NULL, options_handle_client, option_string, offsetof(options_t, client) },
#endif
