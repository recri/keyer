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

  keyer_tone generates an I/Q sine tone keyed by midi events.

  Based on jack-1.9.8/example-clients/midisine.c
  and from dttsp-cgran-r624/src/cwtones.c

    - support multiple notes
    - support aftertouch
    - use sine/cosine recursion
    - output I/Q signal
    
  jack-1.9.8/example-clients/midisine.c

    Copyright (C) 2004 Ian Esten

  dttsp-cgran-r624/src/cwtones.c

    Copyright (C) 2005, 2006, 2007 by Frank Brickle, AB2KT and Bob McGwier, N4HY
    Doxygen comments added by Dave Larsen, KV0S

*/
#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1
#define FRAMEWORK_OPTIONS_KEYER_TONE 1

#include "framework.h"		/* moved from three lines lower */
#include "../dspmath/keyed_tone.h"
#include "../dspmath/midi.h"

typedef struct {
#include "framework_options_vars.h"
} options_t;

typedef struct {
  framework_t fw;
  keyed_tone_t tone;
  unsigned long frame;
  int modified;
  options_t opts;
} _t;

static void *_init(void *arg) {
  _t *dp = (_t *) arg;
  if (dp->fw.verbose) fprintf(stderr, "%s:%s:%d init\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__);
  if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _init freq %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.freq);
  if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _init gain %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.gain);
  if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _init rise %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.rise);
  if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _init fall %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.fall);
  if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _init rate %d\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, sdrkit_sample_rate(arg));
  // dp->opts.chan = 1;
  // dp->opts.note = 0;
  void *p = keyed_tone_init(&dp->tone, dp->opts.gain, dp->opts.freq, dp->opts.rise, dp->opts.rise_window, 
			    dp->opts.fall, dp->opts.fall_window, sdrkit_sample_rate(arg));
  if (p != &dp->tone) return p;
  return arg;
}

static void _update(void *arg) {
  _t *dp = (_t *) arg;
  if (dp->modified) {
    if (dp->fw.verbose) fprintf(stderr, "%s:%s:%d _update\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__);
    if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _update freq %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.freq);
    if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _update gain %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.gain);
    if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _update rise %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.rise);
    if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _update fall %.1f\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, dp->opts.fall);
    if (dp->fw.verbose > 1) fprintf(stderr, "%s:%s:%d _update rate %d\n", Tcl_GetString(dp->fw.client_name), __FILE__, __LINE__, sdrkit_sample_rate(arg));
    dp->modified = dp->fw.busy = 0;
    keyed_tone_update(&dp->tone, dp->opts.gain, dp->opts.freq, dp->opts.rise, dp->opts.rise_window,
		      dp->opts.fall, dp->opts.fall_window, sdrkit_sample_rate(arg));
  }
}

/*
** Jack process callback
*/
static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  float *out_i = jack_port_get_buffer(framework_output(dp,0), nframes);
  float *out_q = jack_port_get_buffer(framework_output(dp,1), nframes);
  framework_midi_event_init(&dp->fw, NULL, nframes);
  /* possibly implement updated options */
  _update(dp);
  /* avoid denormalized numbers */
  AVOID_DENORMALS;
  /* for all frames in the buffer */
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    jack_midi_event_t event;
    int port;
    while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
      if (event.size == 3) {
	char channel = (event.buffer[0]&0xF)+1;
	char note = event.buffer[1];
	if (channel == dp->opts.chan && note == dp->opts.note) {
	  switch (event.buffer[0]&0xF0) {
	  case MIDI_NOTE_OFF: keyed_tone_off(&dp->tone); break;
	  case MIDI_NOTE_ON:  keyed_tone_on(&dp->tone); break;
	  }
	}
      }
    }
    /* compute samples */
    float complex z = keyed_tone_process(&dp->tone);
    *out_i++ = crealf(z);
    *out_q++ = cimagf(z);

    /* increment frame counter */
    dp->frame += 1;
  }
  return 0;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *dp = (_t *)clientData;
  float save_freq = dp->opts.freq, save_gain = dp->opts.gain, save_rise = dp->opts.rise, save_fall = dp->opts.fall;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  dp->modified = dp->fw.busy = dp->modified || 
    (save_freq != dp->opts.freq) || (save_gain != dp->opts.gain || save_rise != dp->opts.rise || save_fall != dp->opts.fall);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
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
  0, 2, 1, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component that translates a MIDI key signal into an I/Q oscillator audio signal"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Keyer_tone_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::keyer-tone", "1.0.0", "sdrtcl::keyer-tone", _factory);
}

