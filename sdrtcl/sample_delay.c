/* -*- mode: c++; tab-width: 8 -*- */
/*
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
** sample delay line
*/

#define FRAMEWORK_USES_JACK 1

#include "framework.h"


typedef struct {
  int delay;			/* sample delay */
} options_t;

typedef struct {
  float *ring;
  size_t rdptr, wrptr, size, mask;
} sample_ring_buffer_t;

static inline void sample_ring_buffer_free(sample_ring_buffer_t *rb) {
  if (rb->ring != NULL) {
    Tcl_Free((char *)rb->ring);
    rb->ring = NULL;
  }
}
static inline void *sample_ring_buffer_init(sample_ring_buffer_t *rb, size_t size) { 
  // fprintf(stderr, "srb_init({%8ld %8ld %8ld %8lx %8p} %ld)\n", rb->rdptr, rb->wrptr, rb->size, rb->mask, rb->ring, size);
  if (((size-1) & size) != 0) return "float ring buffer size must be power of two";
  rb->ring = (float *)Tcl_AttemptRealloc((char *)rb->ring, size*sizeof(float));
  if (rb->ring == NULL) return "float ring buffer allocation failed";
  rb->size = size;
  rb->mask = rb->size-1;
  rb->rdptr = rb->wrptr = 0; 
  return rb;
}
static inline int sample_ring_buffer_can_read(sample_ring_buffer_t *rb) { return (rb->wrptr - rb->rdptr) & rb->mask; }
static inline float sample_ring_buffer_read(sample_ring_buffer_t *rb) { return rb->ring[rb->rdptr++ & rb->mask]; }
static inline int sample_ring_buffer_can_write(sample_ring_buffer_t *rb) { return rb->size - sample_ring_buffer_can_read(rb); }
static inline void sample_ring_buffer_write(sample_ring_buffer_t *rb, float sample) { rb->ring[rb->wrptr++ & rb->mask] = sample; }

typedef struct {
  framework_t fw;
  options_t opts;
  // is this tap running
  int started;
  // implementation
  sample_ring_buffer_t ring;
} _t;

/*
** release the memory allocated
*/
static void _delete_impl(_t *data) {
  sample_ring_buffer_free(&data->ring);
}

// from the bit twiddle collection
unsigned upper_power_of_two(unsigned v)
{
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    return v;
}

/*
** configure a new delay line, two samples per frame
*/
static void *_configure_impl(_t *data) {
  if (data->opts.delay < 0) return "delay must be non-negative";
  void *p = sample_ring_buffer_init(&data->ring, upper_power_of_two(2*(data->opts.delay+1)));
  if (p != &data->ring) return p;
  if (sample_ring_buffer_can_write(&data->ring) < 2*data->opts.delay) {
      sample_ring_buffer_free(&data->ring);
      return "ring buffer overflow while filling up";
  }
  for (int i = 0; i < data->opts.delay; i += 1) {
    sample_ring_buffer_write(&data->ring, 0.0f);
    sample_ring_buffer_write(&data->ring, 0.0f);
  }
  return data;
}

static void *_configure(_t *data) {
  int started = data->started;
  data->started = 0;		// this may not be as safe as I thought it was
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
    float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
    float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
    float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
    float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
    for (int i = 0; i < nframes; i += 1) {
      sample_ring_buffer_write(&data->ring, *in0++);
      sample_ring_buffer_write(&data->ring, *in1++);
      *out0++ = sample_ring_buffer_read(&data->ring);
      *out1++ = sample_ring_buffer_read(&data->ring);
    }
  } else {
    float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes);
    float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
    for (int i = 0; i < nframes; i += 1) {
      *out0++ = 0.0f;
      *out1++ = 0.0f;
    }
  }
  return 0;
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
  // fprintf(stderr, "sample-delay: %ld %ld %ld %ld %p %d", data->ring.wrptr, data->ring.rdptr, data->ring.size, data->ring.mask, data->ring.ring, data->started);
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
  if (save.delay != data->opts.delay) {
    void *p = _configure(data);
    if (p != data) return fw_error_str(interp, p);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-delay", "delay", "Delay", "0", fw_option_int, 0, offsetof(_t, opts.delay), "number of sample times to delay" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "start", _start, "start collecting audio" },
  { "state", _state, "are we started?" },
  { "stop", _stop, "stop collecting audio" },
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
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component which delays an IQ sample"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Sample_delay_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::sample-delay", "1.0.0", "sdrtcl::sample-delay", _factory);
}
