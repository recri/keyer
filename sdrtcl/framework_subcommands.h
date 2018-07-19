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
#ifndef FRAMEWORK_SUBCOMMANDS_H
#define FRAMEWORK_SUBCOMMANDS_H
  { "configure", fw_subcommand_configure,   "configure option values, or get list of options" },
  { "cget",      fw_subcommand_cget,        "get an option value" },
  { "cset",      fw_subcommand_configure,   "set an option value" },
  { "info",      fw_subcommand_info,        "get the doc string(s) for a command" },
  { "is-busy",   fw_subcommand_is_busy,     "see if the command will throw a busy error if we access it" },
#if FRAMEWORK_USES_JACK
  { "activate",  fw_subcommand_activate,    "activate a jack client" },
  { "deactivate",fw_subcommand_deactivate,  "deactivate a jack client" },
  { "is-active", fw_subcommand_is_active,   "test if a jack client is active" },
#endif
#else
#error "framework_subcommands.h multiply included"
#endif
