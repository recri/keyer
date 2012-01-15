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

#include <math.h>

#include "framework.h"

/*
** Create an audio tap to extract samples for processing outside
** the Jack process thread in Tcl.
**
** The buffer is _N_MILLI_SECONDS * sample_rate * 2 floats, rounded up** to a power of two.
**
** A separate buffer is kept for the I and Q channels.
**
** Tcl gets the most recent chunk available along with the frame time for
** the start of the chunk for the size requested.  And the result byte
** array is floats interleaved i/q by sample, so I don't have to explain
** why it isn't.
**
** Now I wonder why it isn't the other way, which would be more convenient
** for scoping.  Hmm.
**
** So this should:
** [x]  allow configuration of the buffer size
** [x]  allow getting the samples as array of complex
** [x]  allow getting the samples as array of i and array of q
** [x]  be named iq-tap or audio-tap
** [ ]  allow getting only i or q
** [ ]  store the samples directly into the byte arrays
*/

typedef struct {
  int log2_buff_n;		/* number of Tcl byte arrays allocated */
  int log2_buff_size;		/* number of jack_buffer_size*2 samples per buffer */
  int complex;			/* if the results should be formatted as complex pairs */
} options_t;

typedef struct {
  // common
  int b_size;		        /* size of jack buffer in samples */
  // output implementation
  int buff_n;			/* number of buffers allocated */
  int buff_i;			/* least recently used buffer */
  int buff_size;		/* sizeof buffer in jack_buffer_size */
  Tcl_Obj **buff;		/* the byte arrays allocated */
  // input implementation
  size_t size;			// number of floats allocated
  float *ibuffer;		// input buffer for i samples
  float *qbuffer;		// input buffer for q samples
  jack_nframes_t wframe;	// current write frame time
  jack_nframes_t rframe;	// current read frame time
} impl_t;
  
typedef struct {
  framework_t fw;
  options_t opts;
  impl_t *current, *next, *last, cache[2];
} _t;

/*
** release the memory successfully allocated for an audio tap
*/
static void _delete_impl(impl_t *p) {
  if (p->buff != NULL) {
    for (int i = 0; i < p->buff_n; i += 1) {
      if (p->buff[i] != NULL)
	Tcl_DecrRefCount(p->buff[i]);
    }
    Tcl_Free((char *)p->buff);
  }
  if (p->ibuffer != NULL) {
    Tcl_Free((char *)p->ibuffer);
  }
  if (p->qbuffer != NULL) {
    Tcl_Free((char *)p->qbuffer);
  }
}

/*
** configure a new audio tap set up into which ever cache isn't active
*/
static void *_configure_impl(_t *data, impl_t *p) {
  memset(p, 0, sizeof(impl_t));
  p->b_size = sdrkit_buffer_size(data);		/* size of jack buffer (samples) */
  p->buff_n = 1<<data->opts.log2_buff_n;	/* number of buffers (n) */
  p->buff = (Tcl_Obj **)Tcl_Alloc(p->buff_n*sizeof(Tcl_Obj *));
  if (p->buff == NULL) {
    return "allocation failed #1";
  }
  p->buff_size = 1<<data->opts.log2_buff_size;	/* number of sample pairs in each buffer (bsize) */
  p->size = 2*p->buff_n*p->buff_size;		/* total number of samples buffered from jack */
  p->ibuffer = (float *)Tcl_Alloc(p->size*sizeof(float));
  if (p->ibuffer == NULL) {
    _delete_impl(p);
    return "allocation failed #2";
  }
  p->qbuffer = (float *)Tcl_Alloc(p->size*sizeof(float));
  if (p->qbuffer == NULL) {
    _delete_impl(p);
    return "allocation failed #3";
  }
  for (int i = 0; i < p->buff_n; i += 1) {
    p->buff[i] = Tcl_NewObj();
    if (p->buff[i] == NULL ||
	Tcl_SetByteArrayLength(p->buff[i], p->buff_size*2*sizeof(float)) == NULL) {
      _delete_impl(p);
      return "allocation failed #4";
    }
    Tcl_IncrRefCount(p->buff[i]);
  }
  p->buff_i = 0; 		/* next buffer to be returned */
  p->wframe = 0;		/* next frame to be written */
  p->rframe = 0;		/* next frame to be read */
  return p;
}

static void *_configure(_t *data) {
  if (data->last != NULL) {
    _delete_impl(data->last);
    data->last = NULL;
  }
  if (data->next != NULL) {
    return "audio-tap implementation cache is in use";
  }
  impl_t *ip = &data->cache[(data->current != &data->cache[0]) ? 0 : 1];
  void *p = _configure_impl(data, ip); if (p != ip) return p;
  data->next = ip;
  // fprintf(stderr, "log2_buff_n = %d, log2_buff_size = %d, complex = %d\n", data->opts.log2_buff_n, data->opts.log2_buff_size, data->opts.complex);
  // fprintf(stderr, "b_size = %d, buff_n = %d, buff_i = %d, buff_size = %d, buff = %lx\n", ip->b_size, ip->buff_n, ip->buff_i, ip->buff_size, (long)ip->buff);
  // fprintf(stderr, "size = %lu, ibuffer = %lx, qbuffer = %lx, wframe = %u, rframe = %u\n", ip->size, (long)ip->ibuffer, (long)ip->qbuffer, ip->wframe, ip->rframe);
  // fprintf(stderr, "current = %lx, next = %lx, last = %lx, &cache[0] = %lx, &cache[1] = %lx\n", (long)data->current, (long)data->next, (long)data->last, (long)&data->cache[0], (long)&data->cache[1]);
  return data;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  memset(&data->cache[0], 0, sizeof(impl_t));
  memset(&data->cache[1], 0, sizeof(impl_t));
  data->current = data->next = data->last = NULL;
  void *p = _configure(data); if (p != data) return p;
  data->current = data->next;
  data->next = NULL;
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  if (data->last != NULL && data->last != data->current) {
    _delete_impl(data->last);
    data->last = NULL;
  }
  if (data->next != NULL && data->next != data->current) {
    _delete_impl(data->next);
    data->next = NULL;
  }
  if (data->current != NULL) {
    _delete_impl(data->current);
    data->current = NULL;
  }
}

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;

  if (data->next != NULL) {
    if (data->last != NULL) {
      fprintf(stderr, "%s:%d: data->last not NULL\n", __FILE__, __LINE__);
    }
    data->last = data->current;
    data->current = data->next;
    data->next = NULL;
  }

  impl_t *p = data->current;
  p->wframe = sdrkit_last_frame_time(arg);

  size_t offset = (p->wframe&(p->size-1));
  if (offset + nframes > p->size) {
    fprintf(stderr, "offset = %ld + nframes = %ld > size = %ld\n", offset, (long)nframes, p->size);
    // need to implement a misaligned copy/set, but I'm betting that jacks frame time is buffer aligned
  } else {
    float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
    if (in0) memcpy(p->ibuffer+offset, in0, nframes*sizeof(float));
    else memset(p->ibuffer+offset, 0, nframes*sizeof(float));

    float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
    if (in1) memcpy(p->qbuffer+offset, in1, nframes*sizeof(float));
    else memset(p->qbuffer+offset, 0, nframes*sizeof(float));
  }

  p->wframe += nframes;

  return 0;
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;

  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }

  // figure out where to read from
  impl_t *p = data->current;
  int max_samples = p->wframe - p->rframe;
  if (max_samples > p->size/2 + p->size/4) {
    max_samples = (p->size/2 + p->size/4);
    p->rframe = p->wframe - max_samples;
  } else if (max_samples < p->buff_size) {
    max_samples = p->buff_size;
    p->rframe = p->wframe - max_samples;
  }
  size_t rptr = p->rframe & (p->size-1);
  Tcl_Obj *result[] = {
    Tcl_NewLongObj(p->rframe), 
    p->buff[p->buff_i++ & (p->buff_n-1)],
    NULL
  };

  if (Tcl_IsShared(result[1])) {
    Tcl_SetResult(interp, "audio-tap return buffer is busy", TCL_STATIC);
    return TCL_ERROR;
  }

  int n_bytes;
  float *samples = (float *)Tcl_GetByteArrayFromObj(result[1], &n_bytes);

  if (samples == NULL) {
    Tcl_SetResult(interp, "audio-tap return buffer is empty", TCL_STATIC);
    return TCL_ERROR;
  }

  if (n_bytes != 2*sizeof(float)*p->buff_size) {
    Tcl_SetResult(interp, "audio-tap return buffer is wrong size", TCL_STATIC);
    return TCL_ERROR;
  }

  p->rframe += p->buff_size;

  if (data->opts.complex) {
    for (int i = p->buff_size; --i >= 0; ) {
      *samples++ = p->ibuffer[rptr];
      *samples++ = p->qbuffer[rptr];
      rptr += 1;
      rptr &= p->size-1;
    }
  } else {
    float *qsamples = samples + p->buff_size;
    for (int i = p->buff_size; --i >= 0; ) {
      *samples++ = p->ibuffer[rptr];
      *qsamples++ = p->qbuffer[rptr];
      rptr += 1;
      rptr &= p->size-1;
    }
  }
  Tcl_SetObjResult(interp, Tcl_NewListObj(2, result));
  return TCL_OK;
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.log2_buff_n != data->opts.log2_buff_n || save.log2_buff_size != data->opts.log2_buff_size) {
    void *p = _configure(data);
    if (p != data) {
      Tcl_SetResult(interp, p, TCL_STATIC);
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
  { "-server",   "server",   "Server",   "default", fw_option_obj,	offsetof(_t, fw.server_name),      "jack server name" },
  { "-client",   "client",   "Client",   NULL,      fw_option_obj,	offsetof(_t, fw.client_name),      "jack client name" },
  { "-log2n",    "log2n",    "Log2n",    "8",	    fw_option_int,	offsetof(_t, opts.log2_buff_n),    "log base 2 of the number of buffers to allocate" },
  { "-log2size", "log2size", "Log2size", "12",	    fw_option_int,	offsetof(_t, opts.log2_buff_size), "log base 2 of the number of samples per buffer" },
  { "-complex",  "complex",  "Complex",  "0",	    fw_option_boolean,	offsetof(_t, opts.complex),        "should the samples be returned as an array of complex values"
  " or as an array of i samples concatenated with an array of q samples."},
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
  { "configure", fw_subcommand_configure },
  { "cget",      fw_subcommand_cget },
  { "cdoc",      fw_subcommand_cdoc },
  { "get",	 _get },
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
  2, 0, 0, 0			// inputs,outputs,midi_inputs,midi_outputs
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Audio_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrkit::audio-tap", "1.0.0", "sdrkit::audio-tap", _factory);
}
