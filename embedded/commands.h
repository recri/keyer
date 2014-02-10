/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2014 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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
#ifndef COMMANDS_H
#define COMMANDS_H
/*
  Implement a Tcl-style command parser that supports:
  1) Multiple commands;
  2) Multiple sub-commands, also known as methods;
  3) Multiple options;
  4) Argument and option validation;
  5) Where commands, sub-commands, options, and option value sets
  are all entered into a single hash table;
  6) Where the readonly strings passed in to define the values
  are kept as the principle copy of each string;
  7) Where the input string is parsed into argument vector words
  which are pointers to the original readonly strings.

  <command-name> cset <option-name> <option-value>
  <command-name> cget <option-name>
  <command-name> info
  <command-name> info methods
  <command-name> info options
  <command-name> info option <option-name>
  <command-name> info method <method-name> [ ... ]

*/

typedef struct {
  // list of commands defined
  _command *commands;
} _table;
typedef struct {
  // list of methods defined for command
  _command *next;
  _word *name;
  _method *methods;
} _command;
typedef struct {
  // list of values defined
  _values *next;
  _word *name;
  _word *values;
} _values;
typedef struct {
  // list of arguments
  _method *next;
  _word *name;
  _arg *args;
} _method;
typedef struct {
  _arg *next;
  _word *name;
  _values *type;
} _method_arg;

/*
  _table *define_table();
  _command *add_command(_table *tab, const char *command_name);
  _method *add_method(_command *cmd, const char *method_word, ...);
  _values *add_value_set(_table *tab, const char *value_name, const char *value, ...);
  _values *add_value_pat(_table *tab, const char *value_name, const char *pattern, ...);
  _method_arg *add_method_arg(_method *mth, const char *arg_name, _value_set *vst);
*/
static const char _cset[] = "cset";
static const char _cget[] = "cget";
static const char _info[] = "info";
static const char _methods[] = "methods";
static const char _options[] = "options";
static const char _method[] = "method";
static const char _option[] = "option";

#endif COMMANDS_H
