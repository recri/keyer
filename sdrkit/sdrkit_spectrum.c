/* -*- mode: c++; tab-width: 8 -*- */

/*
*/

#include "sdrkit.h"
#include "sdrkit_window.h"

#include <complex.h>
#include <fftw3.h>

/*
** reassembling dttsp spectrum computation
**
** spectrum.h -
**	constant definitions
**	SpecBlock data structure
** spectrum.c -
**	snap_spectrum - fill timebuf from accumulator and window
**	snap_scope - steal samples from accumulator for scope
**	compute_spectrum - compute spectrum from timebuf
**	    convert result to Cmag() or Log10P(Csqrmag())
**	    reorder result
**	init_spectrum - initialize
**	reinit_spectrum - reinitialize
**	finish_spectrum
**	NB - nothing that puts data into the accumulator
** sdr.c -
**	do_rx_spectrum - copy samples into accumulator
**	    SPEC_POST_DET uses sqrt(2)*real, 0
**	    otherwise complex sample
** update.c -
**	reqSpectrum - snap_spectrum
**	setSpectrumPolyphase -
**	    if polyphase newFIR_Lowpass_REAL.coeffs -> spec.window
**	    else makewindow
**	setSpectrumWindow - if ! polyphase makewindow
**	setSpectrumType type scale rxk
**      getSpectrumInfo
** sdr-main.c -
**      spectrum_thread -
**	    compute_spectrum or copy spec.oscope
**
** Basically:
**	continuously feed samples into the accumulator
**	on snap_spectrum set up the input
**	  either a simple windowed buffer full
**	  or a fancy polyphase low pass window
**	     over the past 8 buffers
**      on compute_spectrum do the fft and reformat
**	  the output
**
**	the parameters are the size, and the window/polyphase setup
**
*/

/*
** create a spectrum.
** size of spectrum fft as parameter to factory
*/
typedef struct {
  int size;			/* number of complex floats */
  fftwf_complex *in;		/* input array */
  fftwf_complex *out;		/* output array */
  fftwf_plan plan;		/* fftw plan */
  float *window;		/* window */
  float *spectrum;		/* result spectrum */
} _t;

static _t *_init(int size, int planbits) {
  _t *data = (_t *)Tcl_Alloc(sizeof(_t));
  if (data == NULL) return NULL;
  data->size = size;
  fprintf(stderr, "_init data = %lx\n", (long unsigned)data);
  if ((data->in = (fftwf_complex *)fftwf_malloc(data->size*sizeof(fftwf_complex))) &&
      (data->out = data->in) &&
      (data->window = (float *)fftwf_malloc(data->size*sizeof(float))) &&
      (data->spectrum = (float *)fftwf_malloc(data->size*sizeof(float)))) {
    fprintf(stderr, "_init data->in = %lx\n", (long unsigned)data->in);
    fprintf(stderr, "_init data->out = %lx\n", (long unsigned)data->out);
    fprintf(stderr, "_init data->window = %lx\n", (long unsigned)data->window);
    fprintf(stderr, "_init data->spectrum = %lx\n", (long unsigned)data->spectrum);
    data->plan = fftwf_plan_dft_1d(data->size,  data->in, data->out, FFTW_FORWARD, FFTW_ESTIMATE);
    if (planbits != FFTW_ESTIMATE) {
      fftwf_destroy_plan(data->plan);
      data->plan = fftwf_plan_dft_1d(data->size,  data->in, data->out, FFTW_FORWARD, planbits);
    }
    fprintf(stderr, "_init plan completed\n");
    window_make(WINDOW_BLACKMANHARRIS, data->size, data->window);
    fprintf(stderr, "_init window made\n");
    return data;
  } else {
    if (data->in != NULL) fftwf_free(data->in);
    //if (data->out != NULL) fftwf_free(data->out);
    if (data->window != NULL) fftwf_free(data->window);
    if (data->spectrum != NULL) fftwf_free(data->spectrum);
    Tcl_Free((void *)data);
    return NULL;
  }
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  fftwf_destroy_plan(data->plan);
  fftwf_free(data->in);
  // fftwf_free(data->out);
  fftwf_free(data->window);
  fftwf_free(data->spectrum);
  Tcl_Free(arg);
}

/*
** The command executes a complex fft given
** the jack buffer size in which the i and q are interleaved,
** and the input data as a byte array.
** The result is returned as a byte array of float real magnitudes
** ordered from most negative to most positive frequency.
*/
static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  int n;
  float _Complex *input;
  if (argc != 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s byte_array", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  if ((input = (float _Complex *)Tcl_GetByteArrayFromObj(objv[1], &n)) == NULL || n < data->size*2*sizeof(float)) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("byte_array argument does have not %d samples", data->size));
    return TCL_ERROR;
  }
  for (int i = 0; i < data->size; i += 1) {
    data->in[i] = data->window[i] * *input++;
  }
  fftwf_execute(data->plan);
  // magnitude spectrum returns cmagf(result)
  // power spectrum returns Log10P(cmagsqrf(result))
  // return cabsf(result)
  int half = data->size / 2;
  for (int i = 0, j = half; i < half; i++, j++) {
    data->spectrum[i] = cabsf(data->out[j]);
    data->spectrum[j] = cabsf(data->out[i]);
  }
  Tcl_SetObjResult(interp, Tcl_NewByteArrayObj((void *)data->spectrum, data->size));
  return TCL_OK;
}

/*
** The factory command creates an fft spectrum command with specified
** command name, log2_size of fft, and fftw planbits.
*/
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  char *command_name;
  int size = 4096, planbits = 0;
  if (argc == 3 || argc == 4) {
    command_name = Tcl_GetString(objv[1]);
    if (Tcl_GetIntFromObj(interp, objv[2], &size) != TCL_OK) {
      return TCL_ERROR;
    }
    if (argc > 3) {
      if (Tcl_GetIntFromObj(interp, objv[3], &planbits) != TCL_OK) {
	return TCL_ERROR;
      }
    }
    fprintf(stderr, "calling _init(%d, %x)\n", size, planbits);
    _t *data = _init(size, planbits);
    if (data == NULL) {
      Tcl_SetObjResult(interp, Tcl_NewStringObj("allocation failed", -1));
      return TCL_ERROR;
    }
    Tcl_CreateObjCommand(interp, command_name, _command, (ClientData)data, _delete);
    return TCL_OK;
  } else {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("usage: %s command_name [ log2_fft_size [ fftw_planbits] ]", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_spectrum_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::spectrum", _factory);
}
