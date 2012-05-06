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

#include "../dspmath/dspmath.h"
#include "framework.h"

/*
** Create an audio tap to extract samples for processing outside
** the Jack process thread in Tcl.
**
** configured at creation for
**  -log2n <log base 2 number of buffers>
**  -log2size <log base 2 size of buffers in samples,
**	must be greater than jack buffer size>
**  -complex <true if result should be float _Complex iq[pow(2,log2size)]
**	rather than float iq[2*pow(2,log2size] with i samples followed by
**	q samples>
**
** might specialize to allow single channels to be requested at some point
**
** the process callback copies samples, in the format requested, directly into
** pre-allocated Tcl byte arrays.
**
** when the current byte array is filled it marks it as unread and selects the
** oldest unshared byte array to fill next.
**
** the get subcommand returns the oldest unread byte array, or if there are no
** unread arrays it returns an empty byte array.
**
** there is a small race when get goes to grab the next buffer to return, it
** increments the reference count, which makes it shared, then checks to see
** if it's still unread.
*/

typedef struct {
  int log2_buff_n;		/* number of Tcl byte arrays allocated */
  int log2_buff_size;		/* number of jack_buffer_size*2 samples per buffer */
  int as_complex;		/* if the results should be formatted as complex pairs */
} options_t;

typedef struct {
  int bread;			// this buffer has been read
  jack_nframes_t bframe;	// frame time this buffer was filled
  Tcl_Obj *buff;		/* the byte array for this buffer */
} buffer_t;

typedef struct {
  framework_t fw;
  options_t opts;
  // is this tap running
  int started;
  // output implementation
  int buff_n;			/* number of buffers allocated */
  int buff_size;		// size of buffer in samples
  buffer_t *buffs;
  // input implementation
  buffer_t *current;		// current write buffer
} _t;

/*
** release the memory successfully allocated for an audio tap
*/
static void _delete_impl(_t *data) {
  if (data->buffs != NULL) {
    for (int i = 0; i < data->buff_n; i += 1) {
      if (data->buffs[i].buff != NULL)
	Tcl_DecrRefCount(data->buffs[i].buff);
    }
    Tcl_Free((char *)data->buffs);
  }
}

/*
** configure a new audio tap
*/
static void *_configure_impl(_t *data) {
  int b_size = sdrkit_buffer_size(data); /* size of jack buffer (samples) */
  data->buff_n = 1<<data->opts.log2_buff_n;	/* number of buffers (n) */
  data->buff_size = 1<<data->opts.log2_buff_size;	/* number of sample pairs in each buffer (samples) */
  if (data->buff_size < b_size)
    return "audio-tap buffer size must as large as jack buffer size";
  data->buffs = (buffer_t *)Tcl_Alloc(data->buff_n*sizeof(buffer_t));
  if (data->buffs == NULL) {
    return "allocation failed: buff array";
  }
  for (int i = 0; i < data->buff_n; i += 1) {
    data->buffs[i].bread = 1;
    data->buffs[i].bframe = 0;
    data->buffs[i].buff = Tcl_NewObj();
    if (data->buffs[i].buff == NULL ||
	Tcl_SetByteArrayLength(data->buffs[i].buff, data->buff_size*2*sizeof(float)) == NULL) {
      _delete_impl(data);
      return "allocation failed: byte array";
    }
    Tcl_IncrRefCount(data->buffs[i].buff);
  }
  data->current = &data->buffs[0];
  return data;
}

static void *_configure(_t *data) {
  int started = data->started;
  data->started = 0;
  void *p = _configure_impl(data); if (p != data) return p;
  data->started = started;
  return data;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *p = _configure(data); if (p != data) return p;
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  data->started = 0;
  _delete_impl(data);
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  if (data->started) {
    // this will work funny if there are xruns happening, as when we try to use --driver netone 
    jack_nframes_t wframe = sdrkit_last_frame_time(arg);
    size_t offset = (wframe&(data->buff_size-1));
    if (offset + nframes > data->buff_size) {
      fprintf(stderr, "offset = %ld + nframes = %ld > size = %d\n", offset, (long)nframes, data->buff_size);
      // need to implement a misaligned copy/set, but I'm betting that jacks frame time is buffer aligned
      // and I was winning the bet until I tried to use --driver netone
    } else {
      float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
      float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
      int size;
      if (data->opts.as_complex) {
	float complex *out = (float complex *)Tcl_GetByteArrayFromObj(data->current->buff, &size);
	out += offset;
	for (int i = nframes; --i >= 0; )
	  *out++ = *in0++ + I * *in1++;
      } else {
	float *out = (float *)Tcl_GetByteArrayFromObj(data->current->buff, &size);
	out += offset;
	memcpy(out, in0, nframes*sizeof(float));
	out += data->buff_size;
	memcpy(out, in1, nframes*sizeof(float));
      }
      // check for end of current buffer
      if (offset+nframes == data->buff_size) {
	data->current->bframe = wframe - offset;
	data->current->bread = 0;
	for (int i = 0; i < data->buff_n; i += 1)
	  if (data->buffs[i].bframe < data->current->bframe && ! Tcl_IsShared(data->buffs[i].buff))
	    data->current = &data->buffs[i];
	data->current->bread = 1;
      }
    }
  }
  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  if ( ! data->started)
    return fw_error_obj(interp, Tcl_ObjPrintf("audio-tap %s is not running", Tcl_GetString(objv[0])));
  // figure out where to read from
  while (1) {
    // start with no choice
    buffer_t *choice = NULL;
    // look for the oldest unread buffer
    for (int i = 0; i < data->buff_n; i += 1)
      if ( ! data->buffs[i].bread && (choice == NULL || choice->bframe > data->buffs[i].bframe))
	choice = &data->buffs[i];
    // if nothing was found, return an empty string
    if (choice == NULL) {
      Tcl_Obj *result[] = { Tcl_NewLongObj(0), Tcl_NewStringObj("", -1), NULL };
      return fw_success_obj(interp, Tcl_NewListObj(2, result));
    }
    // attempt to grab the choice
    Tcl_IncrRefCount(choice->buff);
    // if it's now marked as read, then the process callback grabbed it
    // loop back and try again
    if (choice->bread) {
      Tcl_DecrRefCount(choice->buff);
      continue;
    }
    // it's ours now that the ref count incremented
    Tcl_Obj *result[] = { Tcl_NewLongObj(choice->bframe), choice->buff, NULL };
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
    Tcl_DecrRefCount(choice->buff);
    choice->bread = 1;
    return TCL_OK;
  }
}
static int _start(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s start", Tcl_GetString(objv[0])));
  data->started = 1;
  return TCL_OK;
}
static int _state(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s state", Tcl_GetString(objv[0])));
  return fw_success_obj(interp, Tcl_NewIntObj(data->started));
}
static int _stop(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s stop", Tcl_GetString(objv[0])));
  data->started = 0;
  return TCL_OK;
}
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.log2_buff_n < data->opts.log2_buff_n || save.log2_buff_size < data->opts.log2_buff_size) {
    void *p = _configure(data);
    if (p != data) return fw_error_str(interp, p);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-log2n",    "log2n",    "Log2n",    "8",	    fw_option_int, 0,			offsetof(_t, opts.log2_buff_n),    "log base 2 of the number of buffers to allocate" },
  { "-log2size", "log2size", "Log2size", "12",	    fw_option_int, 0,			offsetof(_t, opts.log2_buff_size), "log base 2 of the number of samples per buffer" },
  { "-complex",  "complex",  "Complex",  "0",	    fw_option_boolean, 0,		offsetof(_t, opts.as_complex),     "should the samples be returned as an array of complex values"
  " or as an array of i samples concatenated to an array of q samples."},
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get",	 _get,                    "get an audio buffer" },
  { "start",	 _start,		  "start collecting audio" },
  { "state",     _state,		  "are we started?" },
  { "stop",	 _stop,			  "stop collecting audio" },
  { NULL }
};

static const framework_t _template = {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process,			// process callback
  2, 0, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which taps audio signals from Jack to Tcl"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Audio_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::audio-tap", "1.0.0", "sdrtcl::audio-tap", _factory);
}
