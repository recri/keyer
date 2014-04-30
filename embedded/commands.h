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
** The purpose of this is to define Tcl-like commands that are tranmitted
** as MIDI sysex to a USB MIDI device implemented in a Teensy/Arduino.
**
** In addition to the command itself, we need to receive to a roll call message
** and return our command name in response.
**
** The MIDI sysex is structured as:
** uint8_t msg[] = { 0xF0, 0x7D, 0x7C, 0x7B, ..., 0xF7 }
**                   '\xF0', '}', '|', '{', ..., '\xF7' }
**
** the 0xF0 starts the sysex,
** the 0xF7 terminates the sysex,
** the '}' identifies an educational MIDI user,
** the '|' and '{' identify our MIDI uses,
** within the ... we have:
**
**      1) an optional arbitrary length hexadecimal message identifier,
**		identifying this message so it can be referenced
**		in a later signal, response, or error;
**	2) an optional ':' followed by an arbitrary length hexadecimal message identifier,
**		identifying the message this message refers to;
**	3) a '!', '(', ')', or '?' signifying a
**		signal, call, response, or error;
**	4) an ascii string that is the payload
**		of a signal, a call, a response, or an error.
** 
** the message identifier #1 is only required in a call, so its response or error can be matched
** the message identifier #2 is only required in a response or an error.
**
** so the rollcall signal looks like: "\xF0}|{!rollcall\xF7"
** and the response from "key" looks like: "\xF0}|{!present key\xF7"
** and the request to "key" for its option list looks like: "\xF0}|{(key info options\xF7"
**
** The command parser and handler should be separated from the sysex wrapper, it should work
** anywhere.
*/
typedef struct {
  const char *name;
  const char *doc_string;
  method_t *methods;
  option_t *options;
  void *command_data;
} command_t;

typedef struct {
  const char *name;
  const char *doc_string;
  int (*method)(command_t *command, int argc, char *argv[]);
} method_t;

typedef struct {
  const char *name;
  const char *doc_string;
  int (*cset)(command_t *command, option_t *option, int argc, char *argv[]);
  int (*cget)(command_t *command, option_t *option, int argc, char *argv[]);
} option_t;

static const char _cset[] = "cset";
static const char _cget[] = "cget";
static const char _info[] = "info";
static const char _command[] = "command";
static const char _methods[] = "methods";
static const char _options[] = "options";
static const char _method[] = "method";
static const char _option[] = "option";

#define COMMAND_OKAY	0
#define COMMAND_ERROR	1
static void command_set_result(command_t *command, char *result, ...) {
}

static int cset_method(command_t *command, int argc, char *argv[]) {
  if (argc < 4) {
    command_set_result(command, "usage: ", argv[0], " cset -option value", NULL);
    return COMMAND_ERROR;
  }
  for (int i = 0; command->options[i].name != NULL; i += 1)
    if (strcmp(command->options[i].name, argv[2]) == 0)
      return command->options[i].cset(command, argc, argv);
  command_set_result(command, "invalid option: ", argv[2], NULL);
  return COMMAND_ERROR;
}
static int cget_method(command_t *command, int argc, char *argv[]) {
  if (argc < 3) {
    command_set_result(command, "usage: ", argv[0], " cget -option", NULL);
    return COMMAND_ERROR;
  }
  for (int i = 0; command->options[i].name != NULL; i += 1)
    if (strcmp(command->options[i].name, argv[2]) == 0)
      return command->options[i].cget(command, argc, argv);
  command_set_result(command, "invalid option: ", argv[2], NULL);
  return COMMAND_ERROR;
}
static int info_method(command_t *command, int argc, char *argv[]) {
  for (int i = 0; info_methods[i].name != NULL; i += 1)
    if (strcmp(info_methods[i].name, argv[2]) == 0)
      return info_methods[i].method(command, argc, argv);
  command_set_result(command, "invalid method: ", argv[2], NULL);
  return COMMAND_ERROR;
}
static int info_command_method(command_t *command, int argc, char *argv[]) {
}
static int info_methods_method(command_t *command, int argc, char *argv[]) {
}
static int info_options_method(command_t *command, int argc, char *argv[]) {
}
static int info_method_method(command_t *command, int argc, char *argv[]) {
}
static int info_option_method(command_t *command, int argc, char *argv[]) {
}

static const method_t info_methods[] = {
  { _command, "get command description", info_command_method },
  { _methods, "get command methods", info_methods_method },
  { _options, "get command options", info_options_method },
  { _method, "get command method description", info_method_method },
  { _option, "get command option description", info_option_method },
  NULL
};

#define DEFAULT_OPTIONS \

#define DEFAULT_METHODS \
  { _cset, "set an option value", cset_method }, \
  { _cget, "get an option value", cget_method }, \
  { _info, "get information about command", info_method }, \

method_t
#if 0				// for example
static const option_t options[] = {
  { NULL }
};

static const method_t methods[] = {
  DEFAULT_METHODS
  { NULL }
};
#endif

static const method_t info_methods[] = {
  { _command, "get the command description" },
  { _methods, "get the list of methods" },
  { _options, "get the list of options" },
  { _method, "get the method description" },
  { _option, "get the option description" },
  { NULL }
};

#if 0				// for example
static const _command commands[] = {
  { NULL }
};
#endif

static char *argv[16];
static int argc;

#endif COMMANDS_H
