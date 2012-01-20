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
#ifndef FRAMEWORK_OPTIONS_H
#define FRAMEWORK_OPTIONS_H
  { "-server", "server", "Server", "default",  fw_option_obj,	fw_flag_create_only, offsetof(_t, fw.server_name), "jack server name" },
  { "-client", "client", "Client", NULL,       fw_option_obj,	fw_flag_create_only, offsetof(_t, fw.client_name), "jack client name" },
  { "-verbose", "verbose", "Verbose", "0",     fw_option_int,   fw_flag_none,	     offsetof(_t, fw.verbose),   "amount of diagnostic output" },
#else
#error "framework_options.h multiply included"
#endif
