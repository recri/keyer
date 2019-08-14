/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2019 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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
** This component is built to take incoming IQ samples from the hermes lite 2,
** inject them into a running jack server, extract the transmit IQ samples
** from jack, and return them for transmission to the hermes lite.
**
** The incoming IQ samples are 24bits in memory, big-endian, but only the lowest
** 16bits are significant.  If there is more than one receiver running, then the
** receiver samples are interleaved.  There is also a monoaural microphone channel
** interleaved into the buffer as well, 16bits per sample.  The incoming samples 
** may arrive at 48, 96, 192, or 384 ksps, which should match the jack sample rate.
** The incoming samples arrive in the component instance as two 504 byte Tcl binary
** strings, which are the result of two 512 byte USB frames unpacked from a 1032 byte
** UDP packet. 

** We could pass the entire UDP packet with two USB frame offsets as input to the
** component and save any overhead of allocating the substrings.  But we will be
** allocating the two USB frames for the output side, so it makes things more 
** symmetric for the time being.  I'm thinking that the substrings of the incoming
** packet might be allocated with no copy since they are immutable substrings of an
** immutable parent string.
**
** It appears that to avoid extra copying that I will need to allocate Tcl ByteArrays
** and use them as the destination buffer for the samples coming out of Jack.  Skip it
** for the time being.  Oh, I could overwrite the contents of the incoming buffers,
** but that would blow up big time if someone decided to stash a reference to one for
** later examination.
**
** The outgoing IQ samples are 16bits, big-endian, interleaved with a stereo speaker
** channel, always at 48 ksps.  The outgoing samples are returned by the component
** as a list of two 504 byte Tcl binary strings whenever the necessary samples become
** available.
**
** The microphone and speaker channels are ignored by everyone, another hardware
** implementation used them, but there are no audio codecs on this implementation,
** so they may be stuffed with zeroes on the source side and simply dropped on the
** sink side.
**
** This component starts up 2, 4, 6, or 8 jack channels which transfer data into jack,
** 2 for each receiver, and 2 jack channels which transfer data out of jack for the 
** transmitter.
**
** The component is told how many receivers are active.
**
** The jack process handler reads interleaved rx samples from a jack ringbuffer into the jack
** process channels, and reads tx samples from the jack process channels into a second jack
** ringbuffer.
**
** In truth, the only reason to push a rx IQ stream into Jack is to demodulate it one
** or more times.  And we usually only demodulate one channel at a time, the one we're
** operating on.  The other streams turn into spectrum displays which can be computed
** at leisure outside of Jack.  So maybe we do one IQ channel in and one out by notifying
** the component how many receivers are in the input packet and which receiver we want 
** to transfer into Jack.
**
** If we're running at a speed other than 48 ksps, then the transmit stream needs to be
** decimated down to 48 ksps on output.  I suspect that dropping samples is more robust
** than averaging.
**
** usage: %s send rxb1 rxb2 => {} or {txb1 txb2}
**
*/

#define FRAMEWORK_USES_JACK 1

#include "../dspmath/dspmath.h"
#include "framework.h"
#include "jack/ringbuffer.h"

typedef struct {
  int log2_rx_buff_size;		/* size of receiver ringbuffer */
  int log2_tx_buff_size;		/* size of transmitter ringbuffer */
  int n_rx;				/* number of receivers */
  int i_rx;				/* selected receiver index */
  int speed;				/* sample rate of radio rx streams */
} options_t;

typedef struct {
  framework_t fw;
  options_t opts;
  // is this tap running
  int started;
  // tx ringbuffer
  jack_ringbuffer_t *txrb;
  // tx return string buffer
  unsigned char tx_buffer[2*63*8];
  int tx_buffer_i;
  // rx ringbuffer
  jack_ringbuffer_t *rxrb;
  // exception counters
  int rx_overrun, rx_underrun;
  int tx_overrun, tx_underrun;
} _t;

/*
** release the memory successfully allocated for an audio tap
*/
static void _delete_impl(_t *data) {
  if (data->txrb != NULL) jack_ringbuffer_free(data->txrb);
  data->txrb = NULL;
  if (data->rxrb != NULL) jack_ringbuffer_free(data->rxrb);
  data->rxrb = NULL;
}

/*
** configure a new audio tap
*/
static void *_configure_impl(_t *data) {
  int b_size = sdrkit_buffer_size(data);	/* size of jack buffer (samples) */
  int txrb_size = 1<<data->opts.log2_tx_buff_size;
  int rxrb_size = 1<<data->opts.log2_rx_buff_size;
  if (txrb_size < b_size) return "tx buffer size must be as large as jack buffer size";
  if (rxrb_size < b_size) return "rx buffer size must be as large as jack buffer size";
  _delete_impl(data);
  data->rxrb = jack_ringbuffer_create(rxrb_size);
  data->txrb = jack_ringbuffer_create(txrb_size);
  data->tx_buffer_i = 0;
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
    float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
    float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes); /* tx q stream, input from jack, outgoing to radio */
    float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
    float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes); /* rx q stream, incoming from radio, output to jack */
    // use jack_ringbuffer_get_*_vector and jack_ringbuffer_*_advance?
    for (int i = 0; i < nframes; i += 1) {
      if (jack_ringbuffer_write_space(data->txrb) < 2*sizeof(float)) {
	data->tx_overrun += 1;
      } else {
	jack_ringbuffer_write(data->txrb, (char *)(in0+i), sizeof(float));
	jack_ringbuffer_write(data->txrb, (char *)(in1+i), sizeof(float));
      }
      if (jack_ringbuffer_read_space(data->rxrb) < 2*sizeof(float)) {
	data->rx_underrun += 1;
	out0[i] = 0;
	out1[i] = 0;
      } else {
	jack_ringbuffer_read(data->rxrb, (char *)(out0+i), sizeof(float));
	jack_ringbuffer_read(data->rxrb, (char *)(out1+i), sizeof(float));
      }
    }
  }
  return 0;
}

static int _send(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 4)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s send buffer1 buffer2", Tcl_GetString(objv[0])));
  if ( ! data->started)
    return fw_error_obj(interp, Tcl_ObjPrintf("hl-jack %s is not running", Tcl_GetString(objv[0])));
  // input byte arrays
  int n[2];
  unsigned char *in[2] = { Tcl_GetByteArrayFromObj(objv[2], &n[0]), Tcl_GetByteArrayFromObj(objv[3], &n[1]) };
  if (n[0] != 504 || n[1] != 504)
    return fw_error_obj(interp, Tcl_ObjPrintf("%s: badly formed input buffers", Tcl_GetString(objv[0])));
  // convert and copy inputs into local buffer
  const int ninput = 504;
  const int stride = data->opts.n_rx * 6 + 2; /* size of one frame of receiver data */
  const int offset = data->opts.i_rx * 6;     /* offset to IQ for selected receiver */
  for (int i = 0; i < 2; i += 1) {
    unsigned char *input = in[i];
    for (int j = offset; j < ninput; j += stride) {
      short s[2];
      float f[2];
      s[0] = (((signed char *)input)[j+1]<<8 + input[j+2]);
      s[1] = (((signed char *)input)[j+4]<<8 + input[j+5]);
      f[0] = s[0] / 32767.0;
      f[1] = s[1] / 32767.0;
      if (jack_ringbuffer_write_space(data->rxrb) < 2*sizeof(float)) {
	++data->rx_overrun;
      } else {
	jack_ringbuffer_write(data->rxrb, (char *)f, 2*sizeof(float));
      }
    }
  }
  // copy from tx jack ring buffer into local buffer
  while (jack_ringbuffer_read_space(data->txrb) > 2*sizeof(float) && data->tx_buffer_i < sizeof(data->tx_buffer)) {
    float f[2];
    short s[2];
    jack_ringbuffer_read(data->txrb, (char *)f, 2*sizeof(float));
    s[0] = f[0] * 32767;
    s[1] = f[1] * 32767;
    data->tx_buffer[data->tx_buffer_i++] = 0;	/* Left audio channel high byte */
    data->tx_buffer[data->tx_buffer_i++] = 0;	/* Left audio channel low byte */
    data->tx_buffer[data->tx_buffer_i++] = 0;	/* Right audio channel high byte */
    data->tx_buffer[data->tx_buffer_i++] = 0;	/* Right audio channel low byte */
    data->tx_buffer[data->tx_buffer_i++] = s[0]>>8;	/* I sample high byte */
    data->tx_buffer[data->tx_buffer_i++] = s[0];	/* I sample low byte */
    data->tx_buffer[data->tx_buffer_i++] = s[1]>>8;	/* Q sample high byte */
    data->tx_buffer[data->tx_buffer_i++] = s[1];	/* Q sample low byte */
  }
  // decide what to return
  if (data->tx_buffer_i == sizeof(data->tx_buffer)) {
    // if tx buffer is full, convert to TclListObj of Tcl
    data->tx_buffer_i = 0;
    Tcl_Obj *b[2] = { 
		     Tcl_NewByteArrayObj(data->tx_buffer, 504),
		     Tcl_NewByteArrayObj(data->tx_buffer+504, 504)
    };
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, b));
  }
  return TCL_OK;
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
static int _pending(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc == 3) {
    char *cmd = Tcl_GetString(objv[2]);
    if (strcmp(cmd, "input") == 0) {
      // return the bytes to be read in the tx ringbuffer
      return fw_success_obj(interp, Tcl_NewIntObj(jack_ringbuffer_read_space(data->txrb)));
    } else if (strcmp(cmd, "output") == 0) {
      // return the bytes to be read in the rx ringbuffer
      return fw_success_obj(interp, Tcl_NewIntObj(jack_ringbuffer_read_space(data->rxrb)));
    }
  }
  return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s pending input|output", Tcl_GetString(objv[0])));
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  options_t save = data->opts;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  if (save.log2_tx_buff_size != data->opts.log2_tx_buff_size || save.log2_rx_buff_size != data->opts.log2_rx_buff_size) {
    void *p = _configure(data);
    if (p != data) return fw_error_str(interp, p);
  }
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
  #include "framework_options.h"
  { "-log2rxsize", "log2size", "Log2size", "12", fw_option_int, 0, offsetof(_t, opts.log2_rx_buff_size), "log base 2 of ringbuffer size" },
  { "-log2txsize", "log2size", "Log2size", "12", fw_option_int, 0, offsetof(_t, opts.log2_tx_buff_size), "log base 2 of ringbuffer size" },
  { "-n-rx",       "nrx",       "Nrx",       "1", fw_option_int, 0, offsetof(_t, opts.n_rx), "number of receivers" },    
  { "-i-rx",       "irx",       "Irx",       "0", fw_option_int, 0, offsetof(_t, opts.i_rx), "index of active receiver" },
  { "-speed",      "speed",     "Speed", "48000", fw_option_int, 0, offsetof(_t, opts.speed), "sample rate of receivers" },
  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "pending", _pending, "check the ringbuffer fill" },
  { "send", _send, "send rx buffers, return tx buffers" },
  { "start", _start, "start transferring samples" },
  { "state", _state, "are we started?" },
  { "stop", _stop, "stop transferring samples" },
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
  "a component for servicing a hermes lite software defined radio"
};

static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Hl_jack_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::hl-jack", "1.0.0", "sdrtcl::hl-jack", _factory);
}
