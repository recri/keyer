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
  { "-uuid",    "uuid",       "Uuid",    NULL,      fw_option_obj,     fw_flag_create_only, offsetof(_t, fw.uuid_name),   "jack client uuid" },
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
  { "-window",   "window",    "Window",  "hanning", fw_option_custom,  fw_flag_none,	    offsetof(_t, opts.window),    "ramp window", 
      window_mode_custom_option },
#endif
#if FRAMEWORK_OPTIONS_KEYER_SPEED // options that control the speed of morse code
  { "-wpm",      "wpm",       "Words",   "18.0",    fw_option_float,   fw_flag_none,	    offsetof(_t, opts.wpm),	  "words per minute" },
  { "-word",     "word",      "Dits",    "50",      fw_option_int,     fw_flag_none,	    offsetof(_t, opts.word),      "dits in a word" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TIMING_DAH
  { "-dah",      "dah",       "Dits",    "3.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.dah),	  "dah length in dits" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TIMING_IES
  { "-ies",	 "ies",	      "Dits",    "1.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.ies),	  "inter-element space in dits" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TIMING_ILS
  { "-ils",	 "ils",	      "Dits",    "3.0",	    fw_option_float,   fw_flag_none,	    offsetof(_t, opts.ils),	  "inter-letter space in dits" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_TIMING_IWS
  { "-iws",	 "iws",	      "Dits",    "7.0",     fw_option_float,   fw_flag_none,	    offsetof(_t, opts.iws),	  "inter-word space in dits" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_OPTIONS_SWAP
  { "-swap",	 "swap",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.swap),	  "swap the dit and dah paddles" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_OPTIONS_ALSP
  { "-alsp",	 "alsp",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.alsp),	  "auto letter spacing" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_OPTIONS_AWSP
  { "-awsp",	 "awsp",      "Bool",    "0",	    fw_option_boolean, fw_flag_none,	    offsetof(_t, opts.awsp),	  "auto word spacing" },
#endif
#if FRAMEWORK_OPTIONS_KEYER_OPTIONS_MODE
  { "-mode",	 "mode",      "Char",    "A",	    fw_option_char,    fw_flag_none,	    offsetof(_t, opts.mode),	  "iambic keyer mode" },
#endif
#else
#error "framework_options.h multiply included"
#endif
