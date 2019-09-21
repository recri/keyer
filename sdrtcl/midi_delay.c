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
*/

#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_USES_INTERP 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "framework.h"
#include "../dspmath/ring_buffer.h"

/*
** Create a midi event delay.
*/

typedef struct {
#include "framework_options_vars.h"
  float delay;		       /* milliseconds delay */
} options_t;

typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  int delay_samples;
  ring_buffer_t rb;
  unsigned char buff[8192];
} _t;

// update the computed parameters
static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = dp->fw.busy = 0;
    dp->delay_samples = dp->opts.delay * sdrkit_sample_rate(dp) / 1000.0;
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  void *e = ring_buffer_init(&dp->rb, sizeof(dp->buff), dp->buff); if (e != &dp->rb) return e;
  dp->modified = dp->fw.busy = 1;
  _update(dp);
  return arg;
}

static int _writeable(_t *data) {
  return ring_buffer_items_available_to_write(&data->rb) >= 4+sizeof(jack_nframes_t);
}

static void _write(_t *data, jack_nframes_t frame, unsigned char *buff) {
  ring_buffer_put(&data->rb, sizeof(frame), (unsigned char *)&frame);
  ring_buffer_put(&data->rb, 4, buff);
}

static int _readable(_t *data) {
  return ring_buffer_items_available_to_read(&data->rb) >= 4+sizeof(jack_nframes_t);
}
  
static jack_nframes_t _peek_time(_t *dp) {
  jack_nframes_t *framep;
  framep = (jack_nframes_t *)ring_buffer_peek_pointer(&dp->rb, sizeof(*framep));
  return framep == NULL ? 0 : *framep;
}

static int _read(_t *data, jack_nframes_t *framep, unsigned char *bytes) {
  int n = 0;
  n += ring_buffer_get(&data->rb, sizeof(*framep), (unsigned char *)framep);
  n += ring_buffer_get(&data->rb, 4, bytes);
  return n;
}

static void _sendmidi(_t *dp, void *midi_out, jack_nframes_t t, unsigned char midi[3]) {
  unsigned char* buffer = jack_midi_event_reserve(midi_out, t, 3);
  if (buffer == NULL) {
    fprintf(stderr, "jack won't buffer 3 midi bytes!\n");
  } else {
    memcpy(buffer, midi, 3);
  }
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *dp = (_t *)arg;
  void *midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  framework_midi_event_init(&dp->fw, NULL, nframes);
  _update(dp);
  jack_midi_clear_buffer(midi_out);
  /* for all frames in the buffer */
  jack_nframes_t frame = sdrkit_last_frame_time(arg);
  for(int i = 0; i < nframes; i++) {
    /* process all midi events at this sample time */
    /* discard anything with more than 3 bytes of data */
    jack_midi_event_t event;
    int port;
    while (framework_midi_event_get(&dp->fw, i, &event, &port)) {
      if (event.size == 3 && _writeable(dp))
	_write(dp, frame+i+dp->delay_samples, event.buffer);
    }
    while (_readable(dp) && _peek_time(dp) == frame+i) {
      jack_nframes_t mframe;
      unsigned char midi[4];
      _read(dp, &mframe, midi);
      _sendmidi(dp, midi_out, i, midi);
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
  dp->modified = dp->fw.busy = (dp->modified || dp->opts.delay != save.delay);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-delay",   "delay",   "Delay",   "0.0",      fw_option_float, 0, offsetof(_t, opts.delay), "delay of midi events in milliseconds" },
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
  0, 0, 1, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which delays MIDI events in Jack"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

// the initialization function which installs the adapter factory
int DLLEXPORT Midi_delay_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::midi-delay", "1.0.0", "sdrtcl::midi-delay", _factory);
}
