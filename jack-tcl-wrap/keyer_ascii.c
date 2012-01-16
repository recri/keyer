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
/*

  Based on jack-1.9.8/example-clients/midiseq.c and
  dttsp-cgran-r624/src/keyboard-keyer.c

  jack-1.9.8/example-clients/midiseq.c is

    Copyright (C) 2004 Ian Esten

  dttsp-cgran-r624/src/keyboard-keyer.c

    Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
    Doxygen comments added by Dave Larsen, KV0S

*/

#define KEYER_OPTIONS_TIMING	1
#define KEYER_OPTIONS_TONE		1

#include "framework.h"
#include "../sdrkit/midi.h"
#include "../sdrkit/midi_buffer.h"
#include "../sdrkit/morse_timing.h"
#include "../sdrkit/morse_coding.h"

typedef struct {
  #include "keyer_options_var.h"
  Tcl_Obj *dict;
} options_t;

typedef struct {
  framework_t fw;
  morse_timing_t samples_per;
  int modified;
  options_t opts;
  options_t sent;
  Tcl_UniChar prosign[16], n_prosign, n_slash;
  unsigned long frames;
  midi_buffer_t midi;
} _t;

static char *preface(_t *dp, const char *file, int line) {
  static char buff[256];
  sprintf(buff, "%s:%s:%d@%ld", Tcl_GetString(dp->fw.client_name), file, line, dp->frames);
  return buff;
}
  
#define PREFACE	preface(dp, __FILE__, __LINE__)

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;

    if (dp->opts.verbose > 2) fprintf(stderr, "%s _update\n", PREFACE);

    /* update timing computations */
    // maybe this wasn't the best idea
    morse_timing(&dp->samples_per, sdrkit_sample_rate(dp), dp->opts.word, dp->opts.wpm, dp->opts.dah, dp->opts.ies, dp->opts.ils, dp->opts.iws);

    /* pass on parameters to tone keyer */
    char buffer[128];
    if (dp->sent.rise != dp->opts.rise) { sprintf(buffer, "<rise%.1f>", dp->sent.rise = dp->opts.rise); midi_buffer_write_sysex(&dp->midi, buffer); }
    if (dp->sent.fall != dp->opts.fall) { sprintf(buffer, "<fall%.1f>", dp->sent.fall = dp->opts.fall); midi_buffer_write_sysex(&dp->midi, buffer); }
    if (dp->sent.freq != dp->opts.freq) { sprintf(buffer, "<freq%.1f>", dp->sent.freq = dp->opts.freq); midi_buffer_write_sysex(&dp->midi, buffer); }
    if (dp->sent.gain != dp->opts.gain) { sprintf(buffer, "<gain%.1f>", dp->sent.gain = dp->opts.gain); midi_buffer_write_sysex(&dp->midi, buffer); }
    /* or to decoder */
    if (dp->sent.word != dp->opts.word) { sprintf(buffer, "<word%.1f>", dp->sent.word = dp->opts.word); midi_buffer_write_sysex(&dp->midi, buffer); }
    if (dp->sent.wpm != dp->opts.wpm) { sprintf(buffer, "<wpm%.1f>", dp->sent.wpm = dp->opts.wpm); midi_buffer_write_sysex(&dp->midi, buffer); }
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  dp->n_prosign = 0;
  dp->n_slash = 0;
  void *p = midi_buffer_init(&dp->midi); if (p != &dp->midi) return p;
  morse_timing(&dp->samples_per, sdrkit_sample_rate(dp), dp->opts.word, dp->opts.wpm, dp->opts.dah, dp->opts.ies, dp->opts.ils, dp->opts.iws);
  if (dp->opts.dict == NULL) {
    dp->opts.dict = Tcl_NewDictObj();
    Tcl_IncrRefCount(dp->opts.dict);
    for (int i = 0; morse_coding_table[i][0] != NULL; i += 1) {
      Tcl_UniChar ch;
      Tcl_UtfToUniChar(morse_coding_table[i][0], &ch);
      Tcl_DictObjPut(NULL, dp->opts.dict, Tcl_NewUnicodeObj(&ch, 1), Tcl_NewStringObj(morse_coding_table[i][1], -1));
    }
  }
  return arg;
}

/*
** jack process callback
*/
static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void* midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  void* buffer_in = midi_buffer_get_buffer(&dp->midi, nframes, jack_last_frame_time(dp->fw.client));
  int buffer_event_index = 0, buffer_event_time = 0;
  int buffer_event_count = midi_buffer_get_event_count(buffer_in);
  jack_midi_event_t buffer_event;

  // find out what the midi_buffer has for us to do
  if (buffer_event_index < buffer_event_count) {
    midi_buffer_event_get(&buffer_event, buffer_in, buffer_event_index++);
    buffer_event_time = buffer_event.time;
  } else {
    buffer_event_time = nframes+1;
  }

  // clear the jack output buffer
  jack_midi_clear_buffer(midi_out);

  // update our options
  _update(dp);

  // for each frame in this callback
  for(int i = 0; i < nframes; i += 1) {
    // process all midi output events at this sample frame
    while (buffer_event_time == i) {
      if (buffer_event.size != 0) {
	unsigned char* buffer = jack_midi_event_reserve(midi_out, i, buffer_event.size);
	if (buffer == NULL) {
	  fprintf(stderr, "%s:%d:%ld: jack won't buffer %ld midi bytes!\n", __FILE__, __LINE__, dp->frames, buffer_event.size);
	} else {
	  memcpy(buffer, buffer_event.buffer, buffer_event.size);
	}
      }
      if (buffer_event_index < buffer_event_count) {
	midi_buffer_event_get(&buffer_event, buffer_in, buffer_event_index++);
	buffer_event_time = buffer_event.time;
      } else {
	buffer_event_time = nframes+1;
      }
    }
    // bump the frame counter
    dp->frames += 1;
  }
  return 0;
}

static void _flush_midi(_t *dp) {
  midi_buffer_queue_flush(&dp->midi);
}

/*
** queue a string of . and - as midi events
** terminate with an inter letter space unless continues
*/
static void _queue_midi(_t *dp, Tcl_UniChar c, char *p, int continues) {
  /* normal send single character */
  if (p == NULL) {
    if (c == ' ')
      if (dp->opts.verbose > 2) fprintf(stderr, "%s _queue_midi delay %d\n", PREFACE, dp->samples_per.iws-dp->samples_per.ils);
    midi_buffer_queue_delay(&dp->midi, dp->samples_per.iws-dp->samples_per.ils);
  } else {
    while (*p != 0) {
      if (*p == '.') {
	if (dp->opts.verbose > 2) fprintf(stderr, "%s _queue_midi dit %d\n", PREFACE, dp->samples_per.dit);
	midi_buffer_queue_note_on(&dp->midi, dp->samples_per.dit, dp->opts.chan, dp->opts.note, 0);
      } else if (*p == '-') {
	if (dp->opts.verbose > 2) fprintf(stderr, "%s _queue_midi dah %d\n", PREFACE, dp->samples_per.dah);
	midi_buffer_queue_note_on(&dp->midi, dp->samples_per.dah, dp->opts.chan, dp->opts.note, 0);
      }
      if (p[1] != 0 || continues) {
	if (dp->opts.verbose > 2) fprintf(stderr, "%s _queue_midi ies %d)\n", PREFACE, dp->samples_per.ies);
	midi_buffer_queue_note_off(&dp->midi, dp->samples_per.ies, dp->opts.chan, dp->opts.note, 0);
      } else {
	if (dp->opts.verbose > 2) fprintf(stderr, "%s _queue_midi ils %d)\n", PREFACE, dp->samples_per.ils);
	midi_buffer_queue_note_off(&dp->midi, dp->samples_per.ils, dp->opts.chan, dp->opts.note, 0);
      }
      p += 1;
    }
  }
}

static char *morse_unicoding(_t *dp, Tcl_UniChar c) {
  Tcl_Obj *value;
  if (Tcl_DictObjGet(NULL, dp->opts.dict, Tcl_NewUnicodeObj(&c, 1), &value) == TCL_OK && value != NULL)
    return Tcl_GetString(value);
  return NULL;
}

/*
** translate a single character into morse code
** but implement an escape to allow prosign construction
*/
static void _queue_unichar(Tcl_UniChar c, void *arg) {
  _t *dp = (_t *)arg;
  if (dp->opts.verbose) fprintf(stderr, "%s _queue_char('%c')\n", PREFACE, c);
  if (dp->opts.verbose > 1) fprintf(stderr, "%s _queue_char n_slash %d, n_prosign %d\n", PREFACE, dp->n_slash, dp->n_prosign);
  
  if (c == '\\') {
    /* use \ab to send prosign of a concatenated to b with no inter-letter space */
    /* multiple slashes to get longer prosigns, so \\sos or \s\os */
    dp->n_slash += 1;
  } else if (dp->n_slash != 0) {
    dp->prosign[dp->n_prosign++] = c;
    if (dp->n_prosign == dp->n_slash+1) {
      for (int i = 0; i < dp->n_prosign; i += 1) {
	_queue_midi(dp, dp->prosign[i], morse_unicoding(dp, dp->prosign[i]), i != dp->n_prosign-1);
      }
      dp->n_prosign = 0;
      dp->n_slash = 0;
      _flush_midi(dp);
    }
  } else {
    _queue_midi(dp, c, morse_unicoding(dp, c), 0);
    _flush_midi(dp);
  }
}

static int _puts(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  // put the argument strings separated by spaces
  for (int i = 2; i < argc; i += 1) {
    for (Tcl_UniChar *p = Tcl_GetUnicode(objv[i]); *p != 0; p += 1)
      _queue_unichar(*p, clientData);
    if (i != argc-1)
      _queue_unichar(' ', clientData);
  }
  return TCL_OK;
}
static int _pending(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, Tcl_NewIntObj(midi_buffer_readable(&data->midi)));
  return TCL_OK;
}
static int _available(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  Tcl_SetObjResult(interp, Tcl_NewIntObj(midi_buffer_writeable(&data->midi)));
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.word != save.word ||
		    data->opts.wpm != save.wpm ||
		    data->opts.dah != save.dah ||
		    data->opts.ies != save.ies ||
		    data->opts.ils != save.ils ||
		    data->opts.iws != save.iws ||
		    data->opts.freq != save.freq ||
		    data->opts.gain != save.gain ||
		    data->opts.rise != save.rise ||
		    data->opts.fall != save.fall);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "keyer_options_def.h"
  { "-dict",	"dict",     "Morse",  NULL,	  fw_option_dict,  offsetof(_t, opts.dict),	 "morse code dictionary" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
  { "puts",	 _puts },
  { "pending",   _pending },
  { "available", _available },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  NULL,				// delete function
  NULL,				// sample rate function
  _process,			// process callback
  0, 0, 0, 1			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_ascii_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::ascii", "1.0.0", "keyer::ascii", _factory);
}

