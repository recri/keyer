/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA.

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

#include "../dspmath/iambic_vk6ph.h"

extern "C" {

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI	1
#define FRAMEWORK_OPTIONS_KEYER_SPEED_WPM 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_ALSP 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_SWAP 1
  //#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_MODE 1
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_RATIO 1  
#define FRAMEWORK_OPTIONS_KEYER_OPTIONS_TWO 1  

#include "framework.h"
#include "../dspmath/midi.h"

  typedef struct {
#include "framework_options_vars.h"
    char mode;
  } options_t;

  typedef struct {
    framework_t fw;
    int modified;
    options_t opts;
    iambic_vk6ph_t k;
    int raw_dit;
    int raw_dah;
    int key_out;
  } _t;

  // update the computed parameters
  static void _update(_t *dp) {
    if (dp->modified) {
      dp->modified = 0;

      /* keyer recomputation */
      dp->k.k.set_cw_micros_per_tick(1000000.0 / sdrkit_sample_rate(dp));
      dp->k.k.set_cw_keyer_speed(dp->opts.wpm);
      dp->k.k.set_cw_keyer_weight(dp->opts.ratio);
      dp->k.k.set_cw_keyer_spacing(dp->opts.alsp != 0);
      dp->k.k.set_cw_keys_reversed(dp->opts.swap != 0);
      dp->k.k.set_cw_keyer_mode(dp->opts.mode);
    }
  }

  static void *_init(void *arg) {
    _t *dp = (_t *)arg;
    dp->raw_dit = 0;
    dp->raw_dah = 0;
    dp->key_out = 0;
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
    _t *dp = (_t *)clientData;
    options_t save = dp->opts;
    if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
      dp->opts = save;
      return TCL_ERROR;
    }
    dp->modified = dp->modified || dp->opts.wpm != save.wpm || dp->opts.swap != save.swap || 
      dp->opts.mode != save.mode || dp->opts.alsp != save.alsp || dp->opts.ratio != save.ratio ;
    return TCL_OK;
  }

  static const fw_option_table_t _options[] = {
#include "framework_options.h"
 { "-mode", "mode", "Mode", "B", fw_option_char, fw_flag_none, offsetof(_t, opts.mode), "keyer mode: S, A, or B" },
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
    (char *)"an iambic keyer component which translates MIDI input key events into an output MIDI key signal"
  };

  static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
    return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
  }

  // okay, so tcl truncates the name before _Init at the first digit
  int DLLEXPORT Keyer_iambic_vk_Init(Tcl_Interp *interp) {
    return framework_init(interp, "sdrtcl::keyer-iambic-vk6ph", "1.0.0", "sdrtcl::keyer-iambic-vk6ph", _factory);
  }

}
