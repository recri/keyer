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

  Because this now uses a Tcl dict as its morse code table, this is now internationalized.
  The input text strings are in unicode so any text in any language can be specified for
  encoding.  See ~/keyer/lib/morse for morse code mappings for arabic, cyrillic, farsi,
  greek, hebrew, and wabun (the japanese kana coding).
*/

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WPM 1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WORD 1
#define FRAMEWORK_OPTIONS_KEYER_TIMING 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_WEIGHT 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_RATIO 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_COMP 1

#include "../dspmath/midi.h"
#include "../dspmath/midi_buffer.h"
#include "../dspmath/morse_timing.h"
#include "../dspmath/morse_coding.h"
#include "framework.h"

typedef struct {
  #include "framework_options_vars.h"
  Tcl_Obj *dict;
} options_t;

typedef struct {
  framework_t fw;
  morse_timing_t samples_per;	  /* live samples timings per element */
  morse_timing_t pre_samples_per; /* precompute sample timings per element */
  int modified;
  options_t opts;
  int abort;
  Tcl_UniChar prosign[16], n_prosign, n_slash;
  midi_buffer_t midi;
} _t;

static void _update(_t *data) {
  if (data->modified) {
    if (data->fw.verbose > 2) fprintf(stderr, "%s:%d: _update\n", __FILE__, __LINE__);
    /* update timing computations */
    data->samples_per = data->pre_samples_per;
    data->modified = data->fw.busy = 0;
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->n_prosign = 0;
  data->n_slash = 0;
  data->abort = 0;
  void *p = midi_buffer_init(&data->midi); if (p != &data->midi) return p;
  morse_timing(&data->samples_per, sdrkit_sample_rate(data), data->opts.word, data->opts.wpm,
	       data->opts.dit, data->opts.dah, data->opts.ies, data->opts.ils, data->opts.iws,
	       data->opts.weight, data->opts.ratio, data->opts.comp);
  if (data->opts.dict == NULL) {
    data->opts.dict = Tcl_NewDictObj();
    Tcl_IncrRefCount(data->opts.dict);
    for (int i = 0; i < sizeof(morse_coding_table)/sizeof(morse_coding_table[0]); i += 1) {
      Tcl_UniChar ch;
      Tcl_UtfToUniChar(morse_coding_table[i][0], &ch);
      Tcl_DictObjPut(NULL, data->opts.dict, Tcl_NewUnicodeObj(&ch, 1), Tcl_NewStringObj(morse_coding_table[i][1], -1));
    }
  }
  return arg;
}

/*
** jack process callback
*/
static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  void* midi_out = jack_port_get_buffer(framework_midi_output(data,0), nframes);
  jack_midi_event_t event;
  
  // find out what there is to do
  framework_midi_event_init(&data->fw, &data->midi, nframes);
  // clear the jack output buffer
  jack_midi_clear_buffer(midi_out);
  // update our options
  _update(data);
  // handle an abort signal
  if (data->abort) {
    midi_buffer_init(&data->midi);
    unsigned char *buffer = jack_midi_event_reserve(midi_out, 0, 3);
    unsigned char note_off[] = { MIDI_NOTE_ON|(data->opts.chan-1), data->opts.note, 0 };
    if (buffer == NULL) {
      fprintf(stderr, "%s:%d: jack won't buffer %d midi bytes!\n", __FILE__, __LINE__, 3);
    } else {
      memcpy(buffer, note_off, 3);
    }
    data->abort = 0;
    return 0;
  }

  // for each frame in this callback
  for(int i = 0; i < nframes; i += 1) {
    // process all midi output events at this sample frame
    int port;
    while (framework_midi_event_get(&data->fw, i, &event, &port)) {
      if (event.size != 0) {
	unsigned char* buffer = jack_midi_event_reserve(midi_out, i, event.size);
	if (buffer == NULL) {
	  fprintf(stderr, "%s:%d: jack won't buffer %ld midi bytes!\n", __FILE__, __LINE__, (long)event.size);
	} else {
	  memcpy(buffer, event.buffer, event.size);
	}
      }
    }
  }
  return 0;
}

static int _flush_midi(_t *data) {
  return midi_buffer_queue_flush(&data->midi) >= 0;
}

static void _unflush_midi(_t *data) {
  midi_buffer_queue_drop(&data->midi);
}

/*
** queue a string of . and - as midi events
** terminate with an inter letter space unless continues
*/
static int _queue_midi(_t *data, Tcl_UniChar c, char *p, int continues) {
  /* normal send single character */
  if (p == NULL) {
    if (c == ' ') {
      if (midi_buffer_queue_delay(&data->midi, data->samples_per.iws-data->samples_per.ils) < 0) return 0;
    }
  } else {
    while (*p != 0) {
      if (*p == '.') {
	if (midi_buffer_queue_note_on(&data->midi, data->samples_per.dit, data->opts.chan, data->opts.note, 1) < 0) return 0;
      } else if (*p == '-') {
	if (midi_buffer_queue_note_on(&data->midi, data->samples_per.dah, data->opts.chan, data->opts.note, 1) < 0) return 0;
      }
      if (p[1] != 0 || continues) {
	if (midi_buffer_queue_note_on(&data->midi, data->samples_per.ies, data->opts.chan, data->opts.note, 0) < 0) return 0;
      } else {
	if (midi_buffer_queue_note_on(&data->midi, data->samples_per.ils, data->opts.chan, data->opts.note, 0) < 0) return 0;
      }
      p += 1;
    }
  }
  return 1;
}

static char *morse_unicoding(_t *data, Tcl_UniChar c) {
  Tcl_Obj *value;
  if (Tcl_DictObjGet(NULL, data->opts.dict, Tcl_NewUnicodeObj(&c, 1), &value) == TCL_OK && value != NULL)
    return Tcl_GetString(value);
  return NULL;
}

/*
** translate a single character into morse code
** but implement an escape to allow prosign construction
*/
static int _queue_unichar(Tcl_UniChar c, void *arg) {
  _t *data = (_t *)arg;
  
  if (c == '\\') {
    /* use \ab to send prosign of a concatenated to b with no inter-letter space */
    /* multiple slashes to get longer prosigns, so \\sos or \s\os */
    data->n_slash += 1;
  } else if (data->n_slash != 0) {
    data->prosign[data->n_prosign++] = c;
    if (data->n_prosign == data->n_slash+1) {
      for (int i = 0; i < data->n_prosign; i += 1) {
	if ( ! _queue_midi(data, data->prosign[i], morse_unicoding(data, data->prosign[i]), i != data->n_prosign-1)) return 0;
      }
      data->n_prosign = 0;
      data->n_slash = 0;
      _flush_midi(data);
    }
  } else {
    if ( ! _queue_midi(data, c, morse_unicoding(data, c), 0)) return 0;
  }
  return 1;
}

static int _puts(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  // put the argument strings separated by spaces
  for (int i = 2; i < argc; i += 1) {
    for (Tcl_UniChar *p = Tcl_GetUnicode(objv[i]); *p != 0; p += 1) {
      if ( ! _queue_unichar(*p, clientData)) {
	_unflush_midi(clientData);
	return fw_error_str(interp, "buffer overflow");
      }
    }
    if (i != argc-1) {
      if ( ! _queue_unichar(' ', clientData)) {
	_unflush_midi(clientData);
	return fw_error_str(interp, "buffer overflow");
      }
    }
  }
  if ( ! _flush_midi(clientData)) {
    _unflush_midi(clientData);
    return fw_error_str(interp, "buffer overflow");
  }
  return TCL_OK;
}
static int _abort(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_str(interp, "usage: command abort");
  data->abort = 1;
  return TCL_OK;
}
static int _pending(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_str(interp, "usage: command pending");
  Tcl_SetObjResult(interp, Tcl_NewIntObj(midi_buffer_readable(&data->midi)));
  return TCL_OK;
}
static int _available(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2)
    return fw_error_str(interp, "usage: command available");
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

  if ( data->opts.wpm != save.wpm ||
       data->opts.weight != save.weight || data->opts.ratio != save.ratio || data->opts.comp != save.comp ||
       data->opts.dit != save.dit || data->opts.dah != save.dah || data->opts.word != save.word ||
       data->opts.ies != save.ies || data->opts.ils != save.ils || data->opts.iws != save.iws ) {
    morse_timing(&data->pre_samples_per, sdrkit_sample_rate(data), data->opts.word, data->opts.wpm, 
		 data->opts.dit, data->opts.dah, data->opts.ies, data->opts.ils, data->opts.iws,
		 data->opts.weight, data->opts.ratio, data->opts.comp);
    data->modified = data->fw.busy = 1;
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-dict",	"dict",     "Morse",  NULL,	  fw_option_dict, 0,  offsetof(_t, opts.dict),	 "morse code dictionary" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "puts", _puts, "write strings to the queue for conversion to morse code" },
  { "pending", _pending, "how many bytes are queued for conversion to morse"  },
  { "available", _available, "how many bytes are available for queuing" },
  { "abort", _abort, "abort conversion and discard all queued strings" },
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
  0, 0, 0, 1, 1,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "implement a keyboard keyer with a configurable morse code map"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_ascii_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::keyer-ascii", "1.0.0", "sdrtcl::keyer-ascii", _factory);
}

