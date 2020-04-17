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
/* 
embed the dttsp_keyer, more work to do.    
*/


#include "../dspmath/iambic_dttsp.h"

extern "C" {

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WPM 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_SWAP 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_ALSP 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_AWSP 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_MODE 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_WEIGHT 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_TWO 1

#include "framework.h"
#include "../dspmath/midi.h"

  typedef struct {
#include "framework_options_vars.h"
    iambic_dttsp_options_t key_opts;
  } options_t;

  typedef struct {
    framework_t fw;
    iambic_dttsp_t k;
    int modified;
    options_t opts;
    int raw_dit, raw_dah, key_out;
    float millis_per_frame;
  } _t;

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;
      iambic_dttsp_configure(&dp->k, &dp->opts.key_opts);
    }
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    void *p = iambic_dttsp_init(&dp->k, &dp->opts.key_opts); if (p != &dp->k) return p;
    dp->millis_per_frame = 1000.0f / jack_get_sample_rate(dp->fw.client);
    dp->modified = 1;
    return arg;
  }

  /*
  ** jack process callback
  */
  static int _process(jack_nframes_t nframes, void *arg) {
    _t *dp = (_t *)arg;
    void *midi_in = jack_port_get_buffer(framework_midi_input(dp,0), nframes);
    void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);

    // update our timings
    _update(dp);

    /* this is important, very strange if omitted */
    jack_midi_clear_buffer(midi_out);

    /* set up the midi event queue */
    framework_midi_event_init(&dp->fw, NULL, nframes);

    /* for all frames in the buffer */
    for (int i = 0; i < nframes; i++) {

      /* process all midi input events at this sample frame */
      jack_midi_event_t event;
      int port;
      while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
	/* decode the incoming event */
	if (port != 0) continue;
	if (event.size != 3) continue;
	const unsigned char chan = (event.buffer[0]&0xF)+1;
	if (chan != dp->opts.chan) continue;
	const unsigned char note = event.buffer[1];
	const unsigned char comm = event.buffer[0]&0xF0;
	const unsigned char velo = event.buffer[2];
	unsigned char key = 0;
	if (comm == MIDI_NOTE_ON) 
	  key = velo > 0 ? 1 : 0;
	else if (comm != MIDI_NOTE_OFF)
	  continue;
	if (note == dp->opts.note)
	  dp->raw_dit = key;
	else if (note == dp->opts.note+1)
	  dp->raw_dah = key;
      }

      /* clock the iambic keyer */
      const unsigned char new_key_out = dp->k.k.clock(dp->raw_dit, dp->raw_dah, 1);

      /* encode the output event */
      if (new_key_out != dp->key_out) {
	const unsigned char chan = dp->opts.chan;
	const unsigned char note = dp->opts.note;
	unsigned char midi_note_event[3] = { (unsigned char)(MIDI_NOTE_ON|(chan-1)), note, (unsigned char)(new_key_out ? 1 : 0) };
	if (dp->opts.two != 0 && (new_key_out == IAMBIC_DAH || dp->key_out == IAMBIC_DAH)) midi_note_event[1] = note+1;
	jack_midi_event_write(midi_out, i, midi_note_event, 3);
	dp->key_out = new_key_out;
      }
    }
    return 0;
  }

  static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    _t *data = (_t *)clientData;
    options_t save = data->opts;
    if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
      data->opts = save;
      return TCL_ERROR;
    }
    data->modified = data->modified || data->opts.key_opts.wpm != save.key_opts.wpm ||
      data->opts.key_opts.mode != save.key_opts.mode ||
      data->opts.key_opts.want_dit_mem != save.key_opts.want_dit_mem ||
      data->opts.key_opts.want_dah_mem != save.key_opts.want_dah_mem ||
      data->opts.key_opts.need_midelemodeB != save.key_opts.need_midelemodeB ||
      data->opts.key_opts.autocharspacing != save.key_opts.autocharspacing ||
      data->opts.key_opts.autowordspacing != save.key_opts.autowordspacing ||
      data->opts.key_opts.weight != save.key_opts.weight;
    return TCL_OK;
  }

  static const fw_option_table_t _options[] = {
#include "framework_options.h"
    { "-mdit", "mdit",    "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.want_dit_mem), "keep a dit memory" },
    { "-mdah", "mdah",	  "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.want_dah_mem), "keep a dah memory" },
    { "-mide", "mide",    "Memo",    "0",    fw_option_boolean, fw_flag_none, offsetof(_t, opts.key_opts.need_midelemodeB), "remember key state at mid-element" },
    { NULL, NULL, NULL, NULL, fw_option_none, fw_flag_none, 0, NULL }
  };

  static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
    { NULL, NULL }
  };

  static const framework_t _template = {
    _options,			// option table
    _subcommands,		// subcommand table
    _init,			// initialization function
    _command,			// command function
    NULL,			// delete function
    NULL,			// sample rate function
    _process,			// process callback
    0, 0, 1, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
    (char *)"an iambic keyer component based on the dttsp iambic keyer"
  };

  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
  }

  int DLLEXPORT Keyer_iambic_dttsp_Init(Tcl_Interp *interp) {
    return framework_init(interp, "sdrtcl::keyer-iambic-dttsp", "1.0.0", "sdrtcl::keyer-iambic-dttsp", _factory);
  }

}
