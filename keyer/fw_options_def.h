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
#ifndef FW_OPTIONS_DEF_H
#define FW_OPTIONS_DEF_H
  // common options
  { "-server",  "server",  "Server",  "default",  fw_option_obj,   offsetof(_t, fw.server_name), "jack server name" },
  { "-client",  "client",  "Client",  NULL,       fw_option_obj,   offsetof(_t, fw.client_name), "jack client name" },
  { "-verbose", "verbose", "Verbose", "0",	  fw_option_int,   offsetof(_t, verbose),        "amount of diagnostic output" },
  { "-chan",    "channel", "Channel", "1",        fw_option_int,   offsetof(_t, chan),		 "midi channel used for keyer" },
  { "-note",    "note",    "Note",    "0",	  fw_option_int,   offsetof(_t, note),		 "base midi note used for keyer" },
#if FW_OPTIONS_TONE
  // tone options    
  { "-freq",    "frequency","Hertz",  "700.0",	  fw_option_float, offsetof(_t, freq),		 "frequency of tone in hertz" },
  { "-gain",    "gain",     "Decibel","-30.0",    fw_option_float, offsetof(_t, gain),		 "level of tone in decibels" },
  { "-rise",    "rise",     "Ramp",   "5.0",      fw_option_float, offsetof(_t, rise),		 "rise time in milliseconds" },
  { "-fall",    "fall",     "Ramp",   "5.0",      fw_option_float, offsetof(_t, fall),	         "fall time in milliseconds" },
#endif
#if FW_OPTIONS_TIMING
  // timing options
  { "-word",    "word",     "Dits",   "50.0",     fw_option_float, offsetof(_t, word),	         "dits in a word" },
  { "-wpm",     "wpm",      "Words",  "18.0",     fw_option_float, offsetof(_t, wpm),		 "words per minute" },
  { "-dah",     "dah",      "Dits",   "3.0",      fw_option_float, offsetof(_t, dah),		 "dah length in dits" },
  { "-ies",	"ies",	    "Dits",   "1.0",      fw_option_float, offsetof(_t, ies),		 "inter-element space in dits" },
  { "-ils",	"ils",	    "Dits",   "3.0",	  fw_option_float, offsetof(_t, ils),		 "inter-letter space in dits" },
  { "-iws",	"iws",	    "Dits",   "7.0",      fw_option_float, offsetof(_t, iws),		 "inter-word space in dits" },
#endif
#if FW_OPTIONS_KEYER
  // keyer options
  { "-swap",	"swap",	    "Bool",   "0",	  fw_option_bool,  offsetof(_t, swap),		 "swap the dit and dah paddles" },
  { "-alsp",	"alsp",	    "Bool",   "0",	  fw_option_bool,  offsetof(_t, alsp),		 "auto letter spacing" },
  { "-awsp",	"awsp"	    "Bool",   "0",	  fw_option_bool,  offsetof(_t, awsp),		 "auto word spacing" },
  { "-mode",	"mode",	    "Char",   "A",	  fw_option_char,  offsetof(_t, mode),		 "iambic keyer mode" },
#endif
#endif
