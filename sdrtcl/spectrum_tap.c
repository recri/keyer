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
#include <fftw3.h>
#include "../dspmath/window.h"
#include "../dspmath/polyphase_fft.h"

/*
** Tap an audio stream to produce a spectrum.
** Takes the parameters of fftw.c, with respect to size, window, and polyphase.
** Streams incoming samples into one of two fft allocated input buffers.
** When a spectrum is requested via get, the fft/polyphase windowing and fft are
** performed on the complete buffer along with any additional required crunching
** to produce a newly allocated output byte array.
** The process callback continues to fill the other buffer.
*/

typedef enum {
  as_coefficients,		/* return (float complex) fft coefficients */
  as_magnitudes_squared,	/* return (float) magnitude squared */
  as_magnitudes,		/* return (float) magnitude */
  as_decibels,			/* return (float) 10 * log10(magnitude squared) */
  as_decibel_shorts,		/* return (short) 100 * (10 * log10(magnitude squared)) */
  as_decibel_chars		/* return (char) clamp(10 * log10(magnitude squared), -128, 127) */
} result_type_t;

typedef struct {
  // parameters
  int size;			/* size of fft requested */
  int planbits;			/* plan bits for fft */
  int direction;		/* direction of fft */
  int polyphase;		/* number of polyphase buffers */
  Tcl_Obj *result_type_obj;	/* result reduction */
} options_t;

typedef struct {
  // computed results kept for get
  result_type_t result_type;
  float *window;		/* fft/polyphase window */
  // computed results copied into process callback data
  int buf_size;			/* buffer size */
  fftwf_plan plan[2];		/* fftw plans */
  float complex *inout[2];	/* fft input/output buffers */
} preconf_t;

typedef struct {
  framework_t fw;
  options_t opts;
  preconf_t prec;
  int jack_buffer_size;		// 
  int modified;			/* preconf needs to be implemented */
  int writing;			/* which buffer is being written */
  int computing;		/* other buffer is being fft'ed */
  int buf_size;			/* size of buffer being filled */
  int buf_index;		/* index into buffer being filled */
  float complex *inout[2];	/* input/output arrays */
  jack_nframes_t frame[2];	// frame at which buffer was begun
  // cleanup at first opportunity
  int cleanup;			/* cleanup flag */
  float complex *xinout[2];	/* input/output arrays */
} _t;

/*
** cleanup redundant fft stuff.
*/
static void _cleanup(_t *data) {
  if (data->cleanup) {
    data->cleanup = 0;
    if (data->xinout[0] != NULL) { fftwf_free(data->xinout[0]); data->xinout[0] = NULL; }
    if (data->xinout[1] != NULL) { fftwf_free(data->xinout[1]); data->xinout[1] = NULL; }
  }
}

/*
** cleanup allocations in options_t
*/
static void _unpreconfigure(_t *data) {
  if (data->prec.plan[0] != NULL) { fftwf_destroy_plan(data->prec.plan[0]); data->prec.plan[0] = NULL; }
  if (data->prec.plan[1] != NULL) { fftwf_destroy_plan(data->prec.plan[1]); data->prec.plan[1] = NULL; }
  if (data->prec.inout[0] != NULL) { fftwf_free(data->prec.inout[0]); data->prec.inout[0] = NULL; }
  if (data->prec.inout[1] != NULL) { fftwf_free(data->prec.inout[1]); data->prec.inout[1] = NULL; }
  if (data->prec.window != NULL) { fftwf_free(data->prec.window); data->prec.window = NULL; }
}

/*
** release the memory successfully allocated for an spectrum tap
*/
static void _delete(void *arg) {
  _t *data = (_t *)arg;
  _cleanup(data);
  _unpreconfigure(data);
  if (data->inout[0] != NULL) { fftwf_free(data->inout[0]); data->inout[0] = NULL; }
  if (data->inout[1] != NULL) { fftwf_free(data->inout[1]); data->inout[1] = NULL; }
}

/*
** preconfigure a spectrum tap
*/
static void *_preconfigure(_t *data) {
  options_t *opts = &data->opts;
  preconf_t *prec = &data->prec;
  // cleanup remainders
  _cleanup(data);
  // process options
  if (opts->size <= 0) return "size must be greater than zero";
  if (opts->polyphase < 1) return "polyphase must be greater than zero";
  if (opts->direction != FFTW_FORWARD && opts->direction != FFTW_BACKWARD) return "direction must be -1 (forward) or +1 (backward)";
  char *result_type_str = Tcl_GetString(opts->result_type_obj);
  if (strcmp(result_type_str, "") == 0 || strcmp(result_type_str, "coeff") == 0) prec->result_type = as_coefficients;
  else if (strcmp(result_type_str, "mag2") == 0) prec->result_type = as_magnitudes_squared;
  else if (strcmp(result_type_str, "mag") == 0) prec->result_type = as_magnitudes;
  else if (strcmp(result_type_str, "dB") == 0) prec->result_type = as_decibels;
  else if (strcmp(result_type_str, "short") == 0) prec->result_type = as_decibel_shorts;
  else if (strcmp(result_type_str, "char") == 0) prec->result_type = as_decibel_chars;
  else return "result must be one of coeff, mag2, mag, dB, short, or char";
  // cleanup previous configuration
  _unpreconfigure(data);
  // round up buffer size to multiple of jack buffer size
  prec->buf_size = data->jack_buffer_size * ((opts->size * opts->polyphase + data->jack_buffer_size - 1) / data->jack_buffer_size);
  // allocate new fftw buffers, fftw plans, and the window buffer
  if ((prec->inout[0] = (float complex *)fftwf_malloc(prec->buf_size*sizeof(float complex))) == NULL ||
      (prec->plan[0] = fftwf_plan_dft_1d(opts->size,  prec->inout[0], prec->inout[0], opts->direction, opts->planbits)) == NULL ||
      (prec->inout[1] = (float complex *)fftwf_malloc(prec->buf_size*sizeof(float complex))) ==NULL ||
      (prec->plan[1] = fftwf_plan_dft_1d(opts->size,  prec->inout[1], prec->inout[1], opts->direction, opts->planbits)) == NULL ||
      (prec->window = (float *)fftwf_malloc(opts->size*opts->polyphase*sizeof(float))) == NULL) {
    _unpreconfigure(data);
    return "allocation failure";
  }
  if (opts->polyphase == 1)
    window_make(WINDOW_BLACKMAN_HARRIS, opts->size, prec->window);
  else {
    void * e = polyphase_fft_window(opts->polyphase, opts->size, prec->window);
    if (e != prec->window) {
      _unpreconfigure(data);
      return e;
    }
  }
  data->modified = data->fw.busy = 1;
  return data;
}

static void _configure(_t *data) {
  preconf_t *prec = &data->prec;
  // save old buffers and plans for later cleanup
  data->xinout[0] = data->inout[0];
  data->xinout[1] = data->inout[1];
  data->cleanup = 1;
  // initialize index
  data->buf_index = 0;
  // copy in new buffers and plans
  data->buf_size = prec->buf_size;
  data->frame[0] = 0;
  data->inout[0] = prec->inout[0]; prec->inout[0] = NULL;
  data->frame[1] = 0;
  data->inout[1] = prec->inout[1]; prec->inout[1] = NULL;
}

static void _update(_t *data) {
  if (data->modified) {
    _configure(data);
    data->modified = data->fw.busy = 0;
  }
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  data->jack_buffer_size = sdrkit_buffer_size(arg);
  void *p = _preconfigure(data); if (p != data) return p;
  _update(data);
  return arg;
}

// this would be cheaper if we copied the streams in non-interleaved form
// and changed fftw to use the non-interleaved input and output

static int _process(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;

  _update(data);

  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes);
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float complex *out = data->inout[data->writing]+data->buf_index;
  for (int i = 0; i < nframes; i += 1)
    *out++ = *in0++ + I * *in1++;

  if ((data->buf_index += nframes) >= data->buf_size) {
    if (data->buf_index > data->buf_size) {
      fprintf(stderr, "spectrum_tap:_process overran buffer\n");
      exit(5);
    }
    data->frame[data->writing] = sdrkit_last_frame_time(arg)+nframes-data->buf_size;
    // switch buffers if the other buffer is free
    if ( ! data->computing) data->writing ^= 1;
    // start over from the beginning of the buffer
    data->buf_index = 0;
  }

  return 0;
}

static int _get_window(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get-window", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;
  options_t *opts = &data->opts;
  preconf_t *prec = &data->prec;
  return fw_success_obj(interp, Tcl_NewByteArrayObj((unsigned char *)prec->window, opts->polyphase*opts->size*sizeof(float)));
}

static int _get(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s get", Tcl_GetString(objv[0])));
  if ( ! framework_is_active(clientData)) return fw_error_obj(interp, Tcl_ObjPrintf("%s is not active", Tcl_GetString(objv[0])));
  _t *data = (_t *)clientData;

  // mark the fft as active
  data->computing = 1;

  // take the plan and buffer not being written
  options_t *opts = &data->opts;
  preconf_t *prec = &data->prec;
  fftwf_plan plan = prec->plan[data->writing^1];
  float complex *inout = data->inout[data->writing^1];
  jack_nframes_t frame = data->frame[data->writing^1];

  // apply the window
  float complex *in = inout;
  float complex *out = inout;
  float *win = prec->window;
  for (int i = 0; i < opts->size; i += 1) *out++ = *in++ * *win++;
  for (int j = 1; j < opts->polyphase; j += 1) {
    out = inout;
    for (int i = 0; i < opts->size; i += 1) *out++ += *in++ * *win++;
  }

  // compute the fft
  fftwf_execute(plan);

  // reduce the results
  // should probably reorder the coefficients here, too
  Tcl_Obj *result = NULL;
  float norm2 = 1.0f/opts->size;
  float norm = sqrtf(norm2);
  float lognorm2 = log10f(norm2);
  switch (prec->result_type) {
  case as_coefficients:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(float complex));
    float complex *coeff = (float complex *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) coeff[i] = norm * inout[i];
    break;
  case as_magnitudes:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(float));
    float *mag = (float *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) mag[i] = norm * cabsf(inout[i]);
    break;
  case as_magnitudes_squared:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(float));
    float *mag2 = (float *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) mag2[i] = norm2 * cabs2f(inout[i]);
    break;
  case as_decibels:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(float));
    float *dB = (float *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) dB[i] = 10 * (log10f(cabs2f(inout[i]) + 1e-60) + lognorm2);
    break;
  case as_decibel_shorts:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(short));
    short *shorts = (short *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) shorts[i] = (short)(100 * 10 * (log10f(cabs2f(inout[i]) + 1e-60) + lognorm2));
    break;
  case as_decibel_chars:
    result = Tcl_NewByteArrayObj((unsigned char *)inout, opts->size*sizeof(unsigned char));
    unsigned char *chars = (unsigned char *)Tcl_GetByteArrayFromObj(result, NULL);
    for (int i = 0; i < opts->size; i += 1) {
      short t = (short)(10 * (log10f(cabs2f(inout[i]) + 1e-60) + lognorm2));
      chars[i] = (t > 0) ? 0 : (t < -255 ? 255 : -t);
    }
    break;
  } 

  // release the fft buffer
  data->computing = 0;

  // return the results
  if (result != NULL)
    return fw_success_obj(interp, Tcl_NewListObj(2, (Tcl_Obj *[]){ Tcl_NewLongObj(frame), result, NULL }));
  else
    return fw_error_str(interp, "no result computed, how?");
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  Tcl_IncrRefCount(save.result_type_obj);
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) {
    Tcl_DecrRefCount(save.result_type_obj);
    return TCL_ERROR;
  }
  if (save.size != data->opts.size ||
      save.planbits != data->opts.planbits ||
      save.polyphase != data->opts.polyphase ||
      save.direction != data->opts.direction ||
      save.result_type_obj != data->opts.result_type_obj) {
    void *p = _preconfigure(data); if (p != data) {
      Tcl_DecrRefCount(data->opts.result_type_obj);
      data->opts = save;
      return fw_error_str(interp, p);
    }
    Tcl_DecrRefCount(save.result_type_obj);
    if ( ! framework_is_active(data) )
      _update(data);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  { "-size",     "size",     "Samples",   "4096", fw_option_int, 0, offsetof(_t, opts.size),		"size of fft computed" },
  { "-planbits", "planbits", "Planbits",  "0",	  fw_option_int, 0, offsetof(_t, opts.planbits),	"fftw plan bits" },
  { "-direction","direction","Direction", "-1",	  fw_option_int, 0, offsetof(_t, opts.direction),	"fft direction, 1=inverse or -1=forward" },
  { "-polyphase","polyphase","Polyphase", "1",    fw_option_int, 0, offsetof(_t, opts.polyphase),	"polyphase fft, multiple of size to filter" },
  { "-result",   "result",   "Result",    "dB",   fw_option_obj, 0, offsetof(_t, opts.result_type_obj), "result type: coeff, mag, mag2, dB, short, char" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "get-window", _get_window, "get the window used to compute the spectrum" },
  { "get", _get, "get a spectrum" },
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
  "a component which taps baseband signals and computes a spectrum"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Spectrum_tap_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::spectrum-tap", "1.0.0", "sdrtcl::spectrum-tap", _factory);
}
