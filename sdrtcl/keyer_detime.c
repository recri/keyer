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

  keyer_decode reads midi note on and note off, infers a dit clock,
  and produces a string of dits, dahs, and spaces.
    
  It currently gets confused if it starts on something that's all
  dah's and spaces, so I'm cheating and sending the wpm from the
  keyers.  It should wait until it's seen both dits and dahs before
  making its first guesses.

*/

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI	1
#define FRAMEWORK_OPTIONS_KEYER_SPEED	1

#include "framework.h"
#include "../dspmath/midi.h"
#include "../dspmath/ring_buffer.h"
#include "../dspmath/detime.h"

typedef struct {
#include "framework_options_vars.h"
  detime_options_t detime;
} options_t;
  
typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  detime_t detime;
  unsigned frame;
  #define RING_SIZE 512
  ring_buffer_t ring;
  unsigned char buff[RING_SIZE];
} _t;

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = 0;
    dp->opts.detime.word = dp->opts.word;
    dp->opts.detime.wpm = dp->opts.wpm;
    detime_configure(&dp->detime, &dp->opts.detime);
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  dp->opts.detime.sample_rate = sdrkit_sample_rate(&dp->fw);
  dp->opts.detime.word = dp->opts.word;
  dp->opts.detime.wpm = dp->opts.wpm;
  void *p = detime_preconfigure(&dp->detime, &dp->opts.detime); if (p != &dp->detime) return p;
  detime_configure(&dp->detime, &dp->opts.detime);
  ring_buffer_init(&dp->ring, RING_SIZE, dp->buff);
  return arg;
}

static void _detime(_t *dp, unsigned count, unsigned char *p) {
  /* detime note/channel based events */
  if (dp->fw.verbose > 4)
    fprintf(stderr, "%d: _detime(%x, [%x, %x, %x, ...]\n", dp->frame, count, p[0], p[1], p[2]);
  if (count == 3) {
    unsigned char cmd = p[0]&0xF0; 
    unsigned char channel = (p[0]&0xF)+1;
    unsigned char note = p[1];
    if (channel == dp->opts.chan && note == dp->opts.note) {
      char out;
      if (dp->fw.verbose > 4)
	fprintf(stderr, "%d: _detime(%x)\n", dp->frame, cmd);
      if (cmd == MIDI_NOTE_OFF)		/* the end of a dit or a dah */
	out = detime_process(&dp->detime, 0, dp->frame);
      else if (cmd == MIDI_NOTE_ON)	/* the end of an inter-element, inter-letter, or a longer space */
	out = detime_process(&dp->detime, 1, dp->frame);
      else
	return;
      if (out != 0) {
	if (ring_buffer_writeable(&dp->ring)) {
	  ring_buffer_put(&dp->ring, 1, &out);
	} else {
	  fprintf(stderr, "keyer_detime: buffer overflow writing \"%c\"\n", out);
	}
      }
    }
  }
}

/*
** Jack
*/

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  // find out what there is to do
  if (framework_midi_event_init(&dp->fw, NULL, nframes)) {
    /* possibly update the timing parameters */
    _update(dp);
    /* for all frames in the buffer */
    for(int i = 0; i < nframes; i++) {
      /* process all midi events at this sample time */
      jack_midi_event_t event;
      int port;
      while (framework_midi_event_get(&dp->fw, i, &event, &port))
	_detime(dp, event.size, event.buffer);
      /* increment the frame counter */
      dp->frame += 1;
    }
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  // return the current detimed string
  _t *dp = (_t *)clientData;
  // hmm, how to avoid the buffer here, allocate a byte array?
  unsigned n = ring_buffer_items_available_to_read(&dp->ring);
  // fprintf(stderr, "%s:%d %u bytes available\n", __FILE__, __LINE__, n);
  Tcl_Obj *result = Tcl_NewObj();
  char *buff = Tcl_SetByteArrayLength(result, n);
  ring_buffer_get(&dp->ring, n, buff);
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = (data->opts.word != save.word || data->opts.wpm != save.wpm);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",	 _get, "get the currently converted string of dits and dahs" },
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
  0, 0, 1, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which converts midi key on/off events to dits and dahs"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_detime_Init(Tcl_Interp *interp) {
  return framework_init(interp, "keyer::detime", "1.0.0", "keyer::detime", _factory);
}
