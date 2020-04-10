/*
  Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
** filter_goertzel uses a real Goertzel filter to track the power on a specific tone
** running over a 256 sample block at 48000 samples/second, it sees 3.73 cycles of a 700 Hz
** tone per block, yielding a bandwidth of 187.5 filter evaluations per second.
**
** dot length (ms) is 1200/wpm, samples/ms is 48 (for 48000 samples/s)
** 10 wpm dot = 120ms = 5760 samples = 22.5 blocks (of 256 samples)
** 20 wpm dot =  60ms = 2880         = 11.25
** 40 wpm dot =  30ms = 1440	     =  5.625
**
** if we keep a running average of N filter results, the average will cover the last, a float filter power, and a float sum2
*/
#define FRAMEWORK_USES_JACK 1
#define FRAMEWORK_OPTIONS_MIDI 1

#include "../dspmath/filter_goertzel.h"
#define N_MOVING_AVERAGE 512
#include "../dspmath/moving_average.h"
#include "../dspmath/midi.h"
#include "framework.h"

typedef struct {
#include "framework_options_vars.h"
  filter_goertzel_options_t fg;
  moving_average_options_t dbp;
  moving_average_options_t dbe;
  float on_threshold;
  float off_threshold;
} options_t;
  
typedef struct {
  framework_t fw;
  int modified;
  options_t opts;
  filter_goertzel_t fg;
  moving_average_t dbp;	/* moving average of 20*log10(power) */
  moving_average_t dbe;	/* moving average of 20*log10(energy) */
  jack_nframes_t frame;
  float dbpower;		/* 20*log10(power) */
  float dbenergy;		/* 20*log10(energy) */
  int on;
} _t;

static void _update(_t *dp) {
  if (dp->modified) {
    dp->modified = dp->fw.busy = 0;
    filter_goertzel_configure(&dp->fg, &dp->opts.fg);
    moving_average_configure(&dp->dbp, &dp->opts.dbp);
    moving_average_configure(&dp->dbe, &dp->opts.dbe);
  }
}

static void *_init(void *arg) {
  _t *dp = (_t *)arg;
  dp->opts.fg.sample_rate = sdrkit_sample_rate(&dp->fw);
  void *p = filter_goertzel_preconfigure(&dp->fg, &dp->opts.fg); if (p != &dp->fg) return p;
  filter_goertzel_configure(&dp->fg, &dp->opts.fg);
  moving_average_configure(&dp->dbp, &dp->opts.dbp);
  moving_average_configure(&dp->dbe, &dp->opts.dbe);
  dp->on = 0;
  return arg;
}

/*
** Jack
*/

static int _process(jack_nframes_t nframes, void *arg) {
  // get our data pointer
  _t *dp = (_t *)arg;
  // get the input pointer
  float *in = jack_port_get_buffer(framework_input(dp,0), nframes);
  // get the output pointer and buffer
  void* midi_out = jack_port_get_buffer(framework_midi_output(dp,0), nframes);
  jack_midi_data_t cmd;
  // update parameters
  _update(dp);
  // clear the jack output buffer
  jack_midi_clear_buffer(midi_out);
  // for all frames in the buffer
  for (int i = 0; i < nframes; i++) {
    if (filter_goertzel_process(&dp->fg, *in++)) {
      dp->dbpower = 20*log10(maxf(1e-16,dp->fg.power));
      dp->dbenergy = 20*log10(maxf(1e-16,dp->fg.energy));
      moving_average_process(&dp->dbp, dp->dbpower);
      moving_average_process(&dp->dbe, dp->dbenergy);
      /* fprintf(stderr, "power %.3e dbpower %.3f energy %.3e dbenergy %.3f dbp %.3f dbe %3.f\n",
	 dp->fg.power, dp->dbpower, dp->fg.energy, dp->dbenergy, dp->dbp.average, dp->dbe.average); */
      dp->frame = sdrkit_last_frame_time(arg)+i;
      cmd = 0;
      if (dp->on != 0) {
	if (dp->dbpower < dp->dbp.average) {
	  cmd = MIDI_NOTE_OFF;	/* note change off */
	}
      } else {
	if (dp->dbpower > dp->dbp.average) {
	  cmd = MIDI_NOTE_ON;	/* note change on */
	}
      }
      if (cmd != 0) {
	/* prepare to send note change */
	unsigned char* buffer = jack_midi_event_reserve(midi_out, i, 3);
	if (buffer == NULL) {
	  fprintf(stderr, "%s:%d: jack won't buffer %d midi bytes!\n", __FILE__, __LINE__, 3);
	} else {
	  unsigned char note[3] = { MIDI_NOTE_ON | dp->opts.chan-1, dp->opts.note, (cmd == MIDI_NOTE_ON ? 1 : 0) };
	  // fprintf(stderr, "keyer_detone sending %x %x %x\n", note[0], note[1], note[2]);
	  memcpy(buffer, note, 3);
	  dp->on ^= 1;
	}
      }
    }
  }
  return 0;
}

// return a list consisting of:
//   the jack_nframes_t at which the filter computation completed, 
//   the filter result, power in dB, 
//   the sum of squared samples, energy in dB,
//   the running average of powers,
//   the running average of energies
//
static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  return fw_success_obj(interp, 
			Tcl_NewListObj(5, (Tcl_Obj *[]){ 
			    Tcl_NewIntObj(data->frame), 
			      Tcl_NewDoubleObj(data->dbpower), Tcl_NewDoubleObj(data->dbenergy),
			      Tcl_NewDoubleObj(data->dbp.average), Tcl_NewDoubleObj(data->dbe.average),
			      NULL }));
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    data->opts = save;
    return TCL_ERROR;
  }
  data->modified = data->fw.busy = (data->modified || data->opts.fg.hertz != save.fg.hertz || data->opts.fg.bandwidth != save.fg.bandwidth);
  if (data->modified) {
    void *e = filter_goertzel_preconfigure(&data->fg, &data->opts.fg); if (e != &data->fg) {
      data->opts = save;
      data->modified = data->fw.busy = 0;
      return fw_error_str(interp, e);
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-freq",      "frequency", "AFHertz", "700.0", fw_option_float, fw_flag_none, offsetof(_t, opts.fg.hertz),     "frequency to tune in Hz"  },
  { "-bandwidth", "bandwidth", "BWHertz", "375.0", fw_option_float, fw_flag_none, offsetof(_t, opts.fg.bandwidth), "bandwidth of output signal in Hz" },
  { "-on",	  "onThresh",  "Thresh",  "2.0",   fw_option_float, fw_flag_none, offsetof(_t, opts.on_threshold), "on threshold value" },
  { "-off",	  "offThresh", "Thresh",  "1.0",   fw_option_float, fw_flag_none, offsetof(_t, opts.off_threshold),"off threshold value" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get", _get, "fetch the current detected power of the filter" },
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
  1, 0, 0, 1, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which converts audio tone to midi key on/off events"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Filter_goertzel_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::filter-goertzel", "1.0.0", "sdrtcl::filter-goertzel", _factory);
}
