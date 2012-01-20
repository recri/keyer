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
#ifndef KEYER_OPTIONS_DEF_H
#define KEYER_OPTIONS_DEF_H
  // common options
  { "-chan",    "channel", "Channel", "1",        fw_option_int,   fw_flag_none, offsetof(_t, opts.chan),	 "midi channel used for keyer" },
  { "-note",    "note",    "Note",    "0",	  fw_option_int,   fw_flag_none, offsetof(_t, opts.note),	 "base midi note used for keyer" },
#if KEYER_OPTIONS_TONE
  // tone options    
  { "-freq",    "frequency","Hertz",  "700.0",	  fw_option_float, fw_flag_none, offsetof(_t, opts.freq),	 "frequency of tone in hertz" },
  { "-gain",    "gain",     "Decibel","-30.0",    fw_option_float, fw_flag_none, offsetof(_t, opts.gain),	 "level of tone in decibels" },
  { "-rise",    "rise",     "Ramp",   "5.0",      fw_option_float, fw_flag_none, offsetof(_t, opts.rise),	 "rise time in milliseconds" },
  { "-fall",    "fall",     "Ramp",   "5.0",      fw_option_float, fw_flag_none, offsetof(_t, opts.fall),      "fall time in milliseconds" },
#endif
#if KEYER_OPTIONS_TIMING
  // timing options
  { "-word",    "word",     "Dits",   "50.0",     fw_option_float, fw_flag_none, offsetof(_t, opts.word),      "dits in a word" },
  { "-wpm",     "wpm",      "Words",  "18.0",     fw_option_float, fw_flag_none, offsetof(_t, opts.wpm),	 "words per minute" },
  { "-dah",     "dah",      "Dits",   "3.0",      fw_option_float, fw_flag_none, offsetof(_t, opts.dah),	 "dah length in dits" },
  { "-ies",	"ies",	    "Dits",   "1.0",      fw_option_float, fw_flag_none, offsetof(_t, opts.ies),	 "inter-element space in dits" },
  { "-ils",	"ils",	    "Dits",   "3.0",	  fw_option_float, fw_flag_none, offsetof(_t, opts.ils),	 "inter-letter space in dits" },
  { "-iws",	"iws",	    "Dits",   "7.0",      fw_option_float, fw_flag_none, offsetof(_t, opts.iws),	 "inter-word space in dits" },
#endif
#if KEYER_OPTIONS_KEYER
  // keyer options
  { "-swap",	"swap",	    "Bool",   "0",	  fw_option_boolean, fw_flag_none, offsetof(_t, opts.swap),	 "swap the dit and dah paddles" },
  { "-alsp",	"alsp",	    "Bool",   "0",	  fw_option_boolean, fw_flag_none, offsetof(_t, opts.alsp),	 "auto letter spacing" },
  { "-awsp",	"awsp",	    "Bool",   "0",	  fw_option_boolean, fw_flag_none, offsetof(_t, opts.awsp),	 "auto word spacing" },
  { "-mode",	"mode",	    "Char",   "A",	  fw_option_char,    fw_flag_none, offsetof(_t, opts.mode),	 "iambic keyer mode" },
#endif
#endif
