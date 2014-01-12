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
  { "-server",  "server",     "Server",  "default", fw_option_obj,     fw_flag_create_only, offsetof(_t, fw.server_name), "jack server name" },
  { "-client",  "client",     "Client",  NULL,      fw_option_obj,     fw_flag_create_only, offsetof(_t, fw.client_name), "jack client name" },
  { "-verbose", "verbose",    "Verbose", "0",       fw_option_int,     fw_flag_none,	    offsetof(_t, fw.verbose),     "amount of diagnostic output" },
#if FRAMEWORK_OPTIONS_MIDI // options that define the MIDI operation
  { "-chan",     "channel",   "Channel", "1",       fw_option_int,     fw_flag_none,        offsetof(_t, opts.chan),      "midi channel" },
  { "-note",     "note",      "Note",    "0",	    fw_option_int,     fw_flag_none,        offsetof(_t, opts.note),      "base midi note" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TONE // options that control the keyer tone generator
  { "-freq",     "frequency", "Hertz",   "700.0",   fw_option_float,   fw_flag_none,        offsetof(_t, opts.freq),	  "frequency of tone in hertz" },
  { "-gain",     "gain",      "Decibel", "-30.0",   fw_option_float,   fw_flag_none,        offsetof(_t, opts.gain),	  "level of tone in decibels" },
  { "-rise",     "rise",      "Ramp",    "5.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.rise),	  "rise time in milliseconds" },
  { "-fall",     "fall",      "Ramp",    "5.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.fall),      "fall time in milliseconds" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_SPEED // options that control the speed of morse code
  { "-word",     "word",      "Dits",    "50.0",    fw_option_float,   fw_flag_none,	    offsetof(_t, opts.word),      "dits in a word" },
  { "-wpm",      "wpm",       "Words",   "18.0",    fw_option_float,   fw_flag_none,	    offsetof(_t, opts.wpm),	  "words per minute" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TIMING // options that control the timing of morse code elements
  { "-dah",      "dah",       "Dits",    "3.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.dah),	  "dah length in dits" },
  { "-ies",	 "ies",	      "Dits",    "1.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.ies),	  "inter-element space in dits" },
  { "-ils",	 "ils",	      "Dits",    "3.0",	    fw_option_float,   fw_flag_none,	    offsetof(_t, opts.ils),	  "inter-letter space in dits" },
  { "-iws",	 "iws",	      "Dits",    "7.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.iws),	  "inter-word space in dits" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_OPTIONS // options that alter the iambic keyer operation
  { "-swap",	 "swap",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.swap),	  "swap the dit and dah paddles" },
  { "-alsp",	 "alsp",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.alsp),	  "auto letter spacing" },
  { "-awsp",	 "awsp",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.awsp),	  "auto word spacing" },
  { "-mode",	 "mode",      "Char",    "A",	    fw_option_char,    fw_flag_none,	    offsetof(_t, opts.mode),	  "iambic keyer mode" },
#endif
#else
#error "framework_options.h multiply included"
#endif
