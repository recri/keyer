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
** This component interfaces between the HermesLite2 radio and the Jack Audio Kit.
**
** It is called from a Tcl loop that reads udp packets from the HermesLite2,
** gives the rx iq packets to this component, and takes tx iq packets from
** this component, and writes the tx packets to the HermesLite2.
**
** This component takes the incoming IQ samples from the HermesLite2,
** injects them into a running jack server, extracts the transmit IQ samples
** from jack, and return them for transmission to the HermesLite2.
**
** The component maintains the values of the options which are sent to and 
** received from the HermesLite2, the values may also be set or accessed by
** the Tcl script running the component.
**
** The two options which must be set at create time are -n-rx and -speed.  Their
** values are used to patch the component to the correct speed and number of 
** receivers.  Modifying these values involves shutting down and restarting.
*/

#define FRAMEWORK_USES_JACK 1

#include "framework.h"
#include "../dspmath/dspmath.h"
#include "../dspmath/packet_ring_buffer.h"
#include <strings.h>

/*
** this structure describes the options of the hermes lite.
** some of these must be set at creation time, some are set and updated by
** the user during operation of the radio, some are set and updated by 
** information coming back from the radio hardware.
*/

typedef struct {
  /* discovered options */
  int gateware_version;		/* gateware version */
  int board_id;			/* board identifier */
  Tcl_Obj *mac_addr;		/* radio MAC address */
  Tcl_Obj *mcp4662;		/* mcp4662 configuration bytes */
  Tcl_Obj *fixed_ip;		/* firmware assigned ip */
  Tcl_Obj *fixed_mac;		/* firmware assigned mac */
  int n_hw_rx;			/* number of hardware receivers */
  int wb_fmt;			/* format of bandscope samples */
  int build_id;			/* board sub-identifier */
  int gateware_minor;		/* gateware minor version */
  /* control options, sent in transmitter IQ packet headers */
  int mox;			/* enable transmitter */
  int speed;			/* Choose rate of RX IQ samples, sample rate is 48000*2^speed. */
  int filters;			/* Bits which enable filters on the N2ADR filter board. */
  int not_sync;			/* Disable power supply sync. */
  int lna_db;			/* Decibels of low noise amplifier on receive, from -12 to 48. */
  int n_rx;			/* Number of receivers to implement, from 1 to 8 permitted. */
  int duplex;			/* Enable the transmitter frequency to vary independently of the receiver frequencies. */
  int f_tx;			/* Transmitter NCO frequency. */
  int f_rx[12];			/* Receiver 1..12 NCO frequency. */
  int level;			/* Transmitter power level, from 0 to 255. */
  int pa;			/* Enable power amplifier. */
  int low_pwr;			/* Disable T/R relay in low power operation. */
  int pure_signal;		/* Enable Pure Signal operation. Not implemented. */
  int bias_adjust;		/* Enable bias current adjustment for power amplifier. Not implemented. */
  int vna;			/* Enable vector network analysis mode. Not implemented. */
  int vna_count;		/* Number of frequencies sampled in VNA mode. Not implemented. */
  int vna_started;		/* Start VNA mode. Not implemented. */
  /* newer options */
  int vna_fixed_rx_gain;
  int alex_manual_mode;
  int tune_request;
  int i2c_rx_filter;
  int i2c_tx_filter;
  int hermes_lite_lna;
  int cwx;
  int cw_hang_time;
  int tx_buffer_latency;
  int ptt_hang_time;
  int predistortion_subindex;
  int predistortion;
  int reset_hl2_on_disconnect;
  /* feedback options, received in receiver IQ packet headers */
  int hw_dash;			/* The hardware dash key value from the HermesLite. */
  int hw_dot;			/* The hardware dot key value from the HermesLite. */
  int hw_ptt;			/* The hardware ptt value from the HermesLite. */
  int overload;			/* The ADC has clipped values in this frame. */
  int recovery;			/* Under/overflow Recovery (use tx_iq_fifo to distinguish over/under */
  int tx_iq_fifo;		/* TX IQ FIFO Count MSBs */
  int serial;			/* The Hermes software serial number. */
  int temperature;		/* Raw ADC value for temperature sensor, should be averaged. */
  int fwd_power;		/* Raw ADC value for forward power sensor, should be averaged. */
  int rev_power;		/* Raw ADC value for reverse power sensor, should be averaged. */
  int pa_current;		/* Raw ADC value for power amplifier current sensor, should be averaged. */
} options_t;

/*
** packet management structures
**
** packets are 1032 byte udp packets
**   consisting of 8 bytes of header
**   and two 512 byte usb packets 
**       consisting of 3 sync bytes 0x7f, 
**	 5 control/command bytes,
**       504 bytes of sample data
** rx sample data contains 
**   3 bytes of I data,
**   3 bytes of Q data,
**   repeated for each active receiver,
**   2 bytes of microphone sample
** tx sample data contains
**   2 bytes of I data,
**   2 bytes of Q data,
**   2 bytes of L channel audio data
**   2 bytes of R channel audio data
*/

/*
** current active packet for tx or rx samples
*/
typedef struct {
  char *abort;			/* signal something awful happened */
  Tcl_Obj *udp;			/* current udp packet byte array object */
  unsigned char *buff;		/* start of udp packet byte array */
  int i;			/* read/write offset into byte array */
  int limit;			/* sizeof current read/write area */
  int stride;			/* stride of sample frame in usb packet */
  int usb;			/* which usb frame being read/written */
  packet_ring_buffer_t rdy;	/* Tcl_Obj's ready to process, ie tx empty, rx filled */
  packet_ring_buffer_t done;	/* Tcl_Obj's finished processing, ie tx filled, rx emptied */
  unsigned overrun;		/* exception counters */
  unsigned underrun;
  unsigned sequence;		/* packet sequence and header index counters */
  unsigned index;
  unsigned sample;
  unsigned total_overrun;
  unsigned total_underrun;
} packet_t;

typedef struct {
  framework_t fw;		// core framework
  options_t opts;		// options for this component
  int speed_bits;
  int decimate;			// decimation for tx stream
  int process;			// number of process calls
  packet_t rx;			// received packets
  packet_t tx;			// transmit packets
} _t;

static inline Tcl_Obj *_packet_new(void) {
  Tcl_Obj *udp = Tcl_NewByteArrayObj(NULL, 1032);
  memset(Tcl_GetByteArrayFromObj(udp, NULL), 0, 1032);
  Tcl_IncrRefCount(udp);
  return udp;
}

static inline void _packet_init(packet_t *pkt, int stride) {
  pkt->abort = NULL;
  pkt->udp = NULL;
  pkt->buff = NULL;
  pkt->i = 0;
  pkt->limit = 0;
  pkt->stride = stride;
  pkt->usb = 1;
  packet_ring_buffer_init(&pkt->rdy);
  // fprintf(stderr, "_packet_init: rdy can_write %d, can_read %d\n", packet_ring_buffer_can_write(&pkt->rdy), packet_ring_buffer_can_read(&pkt->rdy));
  packet_ring_buffer_init(&pkt->done);
  // fprintf(stderr, "_packet_init: done can_write %d, can_read %d\n", packet_ring_buffer_can_write(&pkt->done), packet_ring_buffer_can_read(&pkt->done));
  pkt->overrun = 0;
  pkt->underrun = 0;
  pkt->sequence = 0;
  pkt->index = 0;
  pkt->sample = 0;
  pkt->total_overrun = 0;
  pkt->total_underrun = 0;
}
static inline void _packet_delete(packet_t *pkt) {
  while (packet_ring_buffer_can_read(&pkt->rdy) > 0) Tcl_DecrRefCount(packet_ring_buffer_read(&pkt->rdy));
  while (packet_ring_buffer_can_read(&pkt->done) > 0) Tcl_DecrRefCount(packet_ring_buffer_read(&pkt->done));
  if (pkt->udp) Tcl_DecrRefCount(pkt->udp);
}
static inline void _packet_next(packet_t *pkt) {
  if (pkt->usb == 0) {
    // finished first usb packet, step to next usb packet
    pkt->usb = 1;
    pkt->i = 528;
    pkt->limit = 528 + 504;
  } else {
    // finished both usb packets, step to next udp packet
    if (pkt->udp != NULL) {
      if (packet_ring_buffer_can_write(&pkt->done)) {
	packet_ring_buffer_write(&pkt->done, pkt->udp);
	pkt->udp = NULL;
      } else {
	pkt->abort = "packet_next: cannot write to done queue";
	// wrong thread for this, so leak memory Tcl_DecrRefCount(pkt->udp);
	pkt->udp = NULL;
      }
    }
    // assert(pkt->udp == NULL);
    if (packet_ring_buffer_can_read(&pkt->rdy)) {
      pkt->udp = packet_ring_buffer_read(&pkt->rdy);
      pkt->buff = Tcl_GetByteArrayFromObj(pkt->udp, NULL);
      pkt->usb = 0;
      pkt->i = 16;
      pkt->limit = 16 + 504;
    } else {
      pkt->abort = "packet_next: cannot read from ready queue";
      pkt->udp = NULL;
    }
  }
}

static void *_configure(_t *data) {
  return data;
}

static void *_init(void *arg) {
  _t *data = (_t *)arg;
  void *p = _configure(data); if (p != data) return p;
  int sr = sdrkit_sample_rate(data);
  if (data->opts.speed != sr)
    return "jack sample rate does not match Hermes Lite sample rate";
  switch (sr) {
  case 48000: data->decimate = 0; data->speed_bits = 0; break;
  case 96000: data->decimate = 1; data->speed_bits = 1; break;
  case 192000: data->decimate = 3; data->speed_bits = 2; break;
  case 384000: data->decimate = 7; data->speed_bits = 3; break;
  default: return "invalid jack sample rate for Hermes Lite operation";
  }
  if (data->opts.n_rx > data->opts.n_hw_rx)
    return "too many receivers for Hermes Lite";
  // fprintf(stderr, "_init: speed %d, speed_bits %d, decimate %d, n-rx %d\n", data->opts.speed, data->speed_bits, data->decimate, data->opts.n_rx);
  _packet_init(&data->rx, data->opts.n_rx*6+2);
  _packet_init(&data->tx, 8);
  for (int i = 0; i < 3; i += 1) {
    // packet_ring_buffer_write(&data->rx.rdy, _packet_new());
    packet_ring_buffer_write(&data->tx.rdy, _packet_new());
  }
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  _packet_delete(&data->rx);
  _packet_delete(&data->tx);
}

/*
** handle transmit samples, at higher sample rates decimate to 48k
*/
static inline void _txiq(_t *data, int i, float *ptri, float *ptrq) {
  if ((data->decimate & i) == 0) {
    if (data->tx.udp == NULL) {
      _packet_next(&data->tx);
      // fprintf(stderr, "_txiq: %d frames\n", (data->tx.limit-data->tx.i) / data->tx.stride);
    }
    if (data->tx.udp == NULL) {
      data->tx.overrun += 1;
    } else {
      data->tx.sample += 1;
      char *const output = data->tx.buff+data->tx.i;
      const short s[2] = { *ptri * 32767, *ptrq * 32767 };
      output[0] = 0;		/* Left audio channel high byte */
      output[1] = 0;		/* Left audio channel low byte */
      output[2] = 0;		/* Right audio channel high byte */
      output[3] = 0;		/* Right audio channel low byte */
      output[4] = s[0]>>8;	/* I sample high byte */
      output[5] = s[0];		/* I sample low byte */
      output[6] = s[1]>>8;	/* Q sample high byte */
      output[7] = s[1];		/* Q sample low byte */
      data->tx.i += data->tx.stride;
      if (data->tx.i + data->tx.stride - 1 > data->tx.limit) {
	_packet_next(&data->tx);
	// fprintf(stderr, "_txiq: %d frames\n", (data->tx.limit-data->tx.i) / data->tx.stride);
      }
    }
  }
}

/*
** handle receive samples
** common begin end wrappers
*/
static inline void _rxiq_start(_t *data) {
  if (data->rx.udp == NULL) {
    _packet_next(&data->rx);
    // fprintf(stderr, "_rxiq_start: %d frames\n", (data->rx.limit-data->rx.i) / data->rx.stride);
  }
}
static inline void _rxiq_finish(_t *data) {
  int nb = data->opts.n_rx*6+2;
  data->rx.i += nb;
  if (data->rx.i + nb - 1 > data->rx.limit) {
    _packet_next(&data->rx);
    // fprintf(stderr, "_rxiq_start: %d frames\n", (data->rx.limit-data->rx.i) / data->rx.stride);
  }
}
/*
** handle first rx stream
*/
#define SAMPLE_NORMALIZE (1.0f / 0x100000) // divide by 2^21
static inline  void _rxiq_1(_t *data, int i, float *ptri, float *ptrq) {
  // convert and copy input samples into jack buffer
  // const int stride = data->opts.n_rx * 6 + 2; /* size of one frame of receiver data */
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri = 0.0;
    *ptrq = 0.0;
  } else {
    data->rx.sample += 1;
    const char *input = data->rx.buff+data->rx.i;
    *ptri = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}
/* process callback for 1 rx */
static int _process_1(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}
/*
** handle second rx stream
*/
static inline  void _rxiq_2(_t *data, int i, float *ptri1, float *ptrq1) {
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri1 = 0.0;
    *ptrq1 = 0.0;
  } else {
    const char *input = data->rx.buff+data->rx.i+6;
    *ptri1 = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq1 = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}
/* process callback for 2 rx */
static int _process_2(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  float *out2 = jack_port_get_buffer(framework_output(arg,2), nframes);
  float *out3 = jack_port_get_buffer(framework_output(arg,3), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_2(data, i, out3++, out2++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}
/*
** handle third rx stream
*/
static inline  void _rxiq_3(_t *data, int i, float *ptri2, float *ptrq2) {
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri2 = 0.0;
    *ptrq2 = 0.0;
  } else {
    const char *input = data->rx.buff+data->rx.i+12;
    *ptri2 = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq2 = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}
/* process callback for 3 rx */
static int _process_3(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  float *out2 = jack_port_get_buffer(framework_output(arg,2), nframes);
  float *out3 = jack_port_get_buffer(framework_output(arg,3), nframes);
  float *out4 = jack_port_get_buffer(framework_output(arg,4), nframes);
  float *out5 = jack_port_get_buffer(framework_output(arg,5), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_2(data, i, out3++, out2++); // note out1 and out0 reversed to fix IQ order
    _rxiq_3(data, i, out5++, out4++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}
/*
** handle fourth rx stream
*/
static inline  void _rxiq_4(_t *data, int i, float *ptri3, float *ptrq3) {
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri3 = 0.0;
    *ptrq3 = 0.0;
  } else {
    const char *input = data->rx.buff+data->rx.i+18;
    *ptri3 = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq3 = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}
/* process callback for 4 rx */
static int _process_4(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  float *out2 = jack_port_get_buffer(framework_output(arg,2), nframes);
  float *out3 = jack_port_get_buffer(framework_output(arg,3), nframes);
  float *out4 = jack_port_get_buffer(framework_output(arg,4), nframes);
  float *out5 = jack_port_get_buffer(framework_output(arg,5), nframes);
  float *out6 = jack_port_get_buffer(framework_output(arg,6), nframes);
  float *out7 = jack_port_get_buffer(framework_output(arg,7), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_2(data, i, out3++, out2++); // note out1 and out0 reversed to fix IQ order
    _rxiq_3(data, i, out5++, out4++); // note out1 and out0 reversed to fix IQ order
    _rxiq_4(data, i, out7++, out6++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}
/*
** handle fifth rx stream
*/
static inline  void _rxiq_5(_t *data, int i, float *ptri4, float *ptrq4) {
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri4 = 0.0;
    *ptrq4 = 0.0;
  } else {
    const char *input = data->rx.buff+data->rx.i+24;
    *ptri4 = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq4 = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}
/* process callback for 5 rx */
static int _process_5(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  float *out2 = jack_port_get_buffer(framework_output(arg,2), nframes);
  float *out3 = jack_port_get_buffer(framework_output(arg,3), nframes);
  float *out4 = jack_port_get_buffer(framework_output(arg,4), nframes);
  float *out5 = jack_port_get_buffer(framework_output(arg,5), nframes);
  float *out6 = jack_port_get_buffer(framework_output(arg,6), nframes);
  float *out7 = jack_port_get_buffer(framework_output(arg,7), nframes);
  float *out8 = jack_port_get_buffer(framework_output(arg,8), nframes);
  float *out9 = jack_port_get_buffer(framework_output(arg,9), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_2(data, i, out3++, out2++); // note out1 and out0 reversed to fix IQ order
    _rxiq_3(data, i, out5++, out4++); // note out1 and out0 reversed to fix IQ order
    _rxiq_4(data, i, out7++, out6++); // note out1 and out0 reversed to fix IQ order
    _rxiq_5(data, i, out9++, out8++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}
/*
** handle sixth rx stream
*/
static inline  void _rxiq_6(_t *data, int i, float *ptri5, float *ptrq5) {
  if (data->rx.udp == NULL) {
    data->rx.underrun += 1;
    *ptri5 = 0.0;
    *ptrq5 = 0.0;
  } else {
    const char *input = data->rx.buff+data->rx.i+30;
    *ptri5 = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8))) * SAMPLE_NORMALIZE;
    *ptrq5 = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8))) * SAMPLE_NORMALIZE;
  }
}

/* process callback for 6 rx */
static int _process_6(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  data->process += 1;
  float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
  float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes);
  float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
  float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes);
  float *out2 = jack_port_get_buffer(framework_output(arg,2), nframes);
  float *out3 = jack_port_get_buffer(framework_output(arg,3), nframes);
  float *out4 = jack_port_get_buffer(framework_output(arg,4), nframes);
  float *out5 = jack_port_get_buffer(framework_output(arg,5), nframes);
  float *out6 = jack_port_get_buffer(framework_output(arg,6), nframes);
  float *out7 = jack_port_get_buffer(framework_output(arg,7), nframes);
  float *out8 = jack_port_get_buffer(framework_output(arg,8), nframes);
  float *out9 = jack_port_get_buffer(framework_output(arg,9), nframes);
  float *out10 = jack_port_get_buffer(framework_output(arg,10), nframes);
  float *out11 = jack_port_get_buffer(framework_output(arg,11), nframes);
  for (int i = 0; i < nframes; i += 1) {
    _txiq(data, i, in0++, in1++);
    _rxiq_start(data);
    _rxiq_1(data, i, out1++, out0++); // note out1 and out0 reversed to fix IQ order
    _rxiq_2(data, i, out3++, out2++); // note out1 and out0 reversed to fix IQ order
    _rxiq_3(data, i, out5++, out4++); // note out1 and out0 reversed to fix IQ order
    _rxiq_4(data, i, out7++, out6++); // note out1 and out0 reversed to fix IQ order
    _rxiq_5(data, i, out9++, out8++); // note out1 and out0 reversed to fix IQ order
    _rxiq_6(data, i, out11++, out10++); // note out1 and out0 reversed to fix IQ order
    _rxiq_finish(data);
  }
  return 0;
}

/*
** translate control bytes from udp packets into hl2_udp_jack options.
*/
static inline void _grabkeyptt(_t *data, unsigned char *c) {
  data->opts.hw_dash = (c[0] & 4) != 0;
  data->opts.hw_dot =  (c[0] & 2) != 0;
  data->opts.hw_ptt =  (c[0] & 1) != 0;
}
static inline void _storeu(unsigned char *p, unsigned f) {
  // these are in network order, big endian
  p += 4;
  *--p = f & 0xff; f >>= 8;
  *--p = f & 0xff; f >>= 8;
  *--p = f & 0xff; f >>= 8;
  *--p = f & 0xff;
}
static inline unsigned _loadu(unsigned char *p) {
  unsigned f = 0;
  f |= *p++; f <<= 8;
  f |= *p++; f <<= 8;
  f |= *p++; f <<= 8;
  f |= *p++;
  return f;
}
static inline void _rxiqscan(_t *data, Tcl_Obj *udp) {
  int n;
  unsigned char * const bytes = Tcl_GetByteArrayFromObj(udp, &n);
  // bytes[0:2] == sync 0xeffe01
  // bytes[3] == end point == 6 for rx iq data
  // bytes[4:7] == sequence number
  unsigned sync = _loadu(bytes+0);
  unsigned seq = _loadu(bytes+4);
  // fprintf(stderr, "_rxiqscan: sync %x seq %x\n", sync, seq);
  for (int i = 8; i <= 520; i += 512) {
    // bytes[8:10] == bytes[520:522] == sync 0x7f 0x7f 0x7f
    // bytes[11:15] == bytes[523:527] == c[0:4] control/command
    //# scan control bytes into option values
    //# I suspect that key and ptt may be in more packets
    //# this switch statement looks suspicious
    // fprintf(stderr, "_rxiqscan: usb packet[i=%d]\n", i);
    unsigned char *c = bytes+i+3;
    switch (c[0]) {
    case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:      
      data->rx.index = 0;
      _grabkeyptt(data, c);
      data->opts.overload = (c[1] & 1) != 0;
      data->opts.recovery = (c[2] & 0x80) != 0;
      data->opts.tx_iq_fifo = c[2] & 0x7f;
      data->opts.serial =  c[4];
      break;
    case 8: case 9: case 10: case 11: case 12: case 13: case 14: case 15:
      data->rx.index = 1;
      _grabkeyptt(data, c);
      data->opts.temperature = (c[1]<<8)|c[2];
      data->opts.fwd_power = (c[3]<<8)|c[4];
      break;
    case 16: case 17: case 18: case 19: case 20: case 21: case 22: case 23:
      data->rx.index = 2;
      _grabkeyptt(data, c);
      data->opts.rev_power = (c[1]<<8)|c[2];
      data->opts.pa_current = (c[3]<<8)|c[4];
      break;
    case 24: case 25: case 26: case 27: case 28: case 29: case 30: case 31:
      data->rx.index = 3;
      break;
    case 32: case 33: case 34: case 35: case 36: case 37: case 38: case 39:
      data->rx.index = 4;
      break;
    case 40: case 41: case 42: case 43: case 44: case 45: case 46: case 47:
      data->rx.index = 5;
      break;
    case 251: case 252: case 253:
      // these are acks to i2c settings
      // need to post the ack to the tx
      // control queue
      break;
    default:
      break;
    }
  }
  // fprintf(stderr, "rxiqscan: finished\n");
}

/*
** translate hl2_udp_jack options into command bytes in udp packets.
*/
static inline void _txiqscan(_t *data, Tcl_Obj *udp) {
  int n;
  unsigned char *const bytes = Tcl_GetByteArrayFromObj(udp, &n);
  bytes[0] = 0xEF;
  bytes[1] = 0xFE;
  bytes[2] = 0x01;
  bytes[3] = 0x02;
  _storeu(bytes+4, data->tx.sequence++);
  for (int i = 8; i <= 520; i += 512) {
    unsigned char *c = bytes+i;
    *c++ = 0x7f;		// usb packet sync bytes
    *c++ = 0x7f;
    *c++ = 0x7f;
    while (1) {
      unsigned c0 = data->tx.index++;
      c[0] = (c0 << 1) | data->opts.mox; // set the addr and the mox bit
      c[1] = c[2] = c[3] = c[4] = 0;	 // clear out any leftover rx bits
      switch (c0) {
      case 0x0:
	// 0x00	[25:24]	Speed (00=48kHz, 01=96kHz, 10=192kHz, 11=384kHz)
	// -speed { set c1234(0) [expr {($c1234(0) & ~(3<<24)) | ([map-speed $val]<<24)}] } # restart requested
	c[1] = data->speed_bits & 3;
	// 0x00	[23:17]	Open Collector Outputs on Penelope or Hermes
	// -filters { set c1234(0) [expr {($c1234(0) & ~(127<<17)) | ($val<<17)}] }
	c[2] = (data->opts.filters & 127) << 1;
	// 0x00	[12]	FPGA-generated power supply switching clock (0=on, 1=off)
	// 0x00	[10]	VNA fixed RX Gain (0=-6dB, 1=+6dB)
	// -not-sync { set c1234(0) [expr {($c1234(0) & ~(1<<12)) | ($val<<12)}] }
	c[3] = ((data->opts.not_sync & 1) << 4) | ((data->opts.vna_fixed_rx_gain & 1) << 2);
	// 0x00	[6:3]	Number of Receivers (0000=1 to max 1011=12)
	// 0x00	[2]	Duplex (0=off, 1=on)
	// -n-rx { set c1234(0) [expr {($c1234(0) & ~(7<<3)) | (($val-1)<<3)}] } # restart requested
	// -duplex { set c1234(0) [expr {($c1234(0) & ~(1<<2)) | ($val<<2)}] }
	c[4] = (((data->opts.n_rx-1) & 7) << 3) | ((data->opts.duplex & 1) << 2);
	break;
      case 0x01:
	// 0x01	[31:0]	TX1 NCO Frequency in Hz
	// -f-tx { set c1234(1) $val }
	_storeu(c+1, data->opts.f_tx);
	break;
      case 0x02: case 0x03: case 0x04: case 0x05: case 0x06: case 0x07: case 0x08: {
	// 0x02	[31:0]	RX1 NCO Frequency in Hz
	// -f-rx1 { set c1234(2) $val }
	// and so on for RX2 .. RX7
	unsigned rxn = c0-0x01;	// 1 based index of receiver
	if (rxn > data->opts.n_rx) continue;
	_storeu(c+1, data->opts.f_rx[rxn-1]);
	break;
      }
      case 0x09:
	// 0x09	[31:24]	Hermes TX Drive Level (only [31:28] used)
	// 0x09	[23]	VNA mode (0=off, 1=on)
	// 0x09	[22]	Alex manual mode (0=off, 1=on) (Not implemented yet)
	// 0x09	[20]	Tune request
	// 0x09	[19]	Onboard PA (0=off, 1=on)
	// 0x09	[18]	Q5 switch external PTT in low power mode
	// 0x09	[15:8]	I2C RX filter (Not implemented), or VNA count MSB
	// 0x09	[7:0]	I2C TX filter (Not implemented), or VNA count LSB
	// -level { set c1234(9) [expr {($c1234(9) & ~(0xFF<<24)) | ($val<<24)}] }
	// -vna { set c1234(9) [expr {($c1234(9) & ~(1<<23)) | ($val<<23)}] }
	// -pa { set c1234(9) [expr {($c1234(9) & ~(1<<19)) | ($val<<19)}] }
	// -low-pwr { set c1234(9) [expr {($c1234(9) & ~(1<<18)) | ($val<<18)}] }
	c[1] = data->opts.level;
	c[2] = ((data->opts.vna & 1) << 7) | ((data->opts.alex_manual_mode & 1) << 6) |
	  ((data->opts.tune_request & 1) << 4) | ((data->opts.pa & 1) << 3) | ((data->opts.low_pwr & 1) << 2);
	if (data->opts.vna) {
	  c[3] = (data->opts.vna_count >> 8) & 0xFF;
	  c[4] = data->opts.vna_count & 0xFF;
	} else {
	  c[3] = data->opts.i2c_rx_filter;
	  c[4] = data->opts.i2c_tx_filter;
	}
	break;
      case 0x0a:
	// 0x0a	[22]	PureSignal (0=disable, 1=enable)
	// 0x0a	[6]	See LNA gain section below
	// 0x0a	[5:0]	LNA[5:0] gain
	// -pure-signal { set c1234(10) [expr {($c1234(10) & ~(1<<22)) | ($val<<22)}] }
	// -lna-db { set c1234(10) [expr {($c1234(10) & ~0x7F) | 0x40 | ($val+12)}] }
	c[2] = ((data->opts.pure_signal & 1) << 6);
	c[4] = ((data->opts.hermes_lite_lna & 1) << 6) | (data->opts.lna_db+12);
	break;
      case 0x0f:
	// 0x0f	[24]	Enable CWX, I[0] of IQ stream is CWX keydown
	c[1] = (data->opts.cwx & 1);
	break;
      case 0x10:
	// 0x10	[31:24]	CW Hang Time in ms, bits [9:2]
	// 0x10	[17:16]	CW Hang Time in ms, bits [1:0]
	c[1] = (data->opts.cw_hang_time & 0x3FB) >> 2;
	c[2] = (data->opts.cw_hang_time & 0x3);
	break;
      case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: {
	// 0x12	[31:0]	If present, RX8 NCO Frequency in Hz
	// and so on for RX9 .. RX12
	unsigned rxn = c0-0x12+8;	// 1 based index of receiver
	if (rxn > data->opts.n_rx) continue;
	_storeu(c+1, data->opts.f_rx[rxn-1]);
	break;
      }
      case 0x17:
	continue;
	// 0x17	[4:0]	TX buffer latency in ms, default is 10ms
	// 0x17	[12:8]	PTT hang time, default is 4ms
	c[3] = data->opts.ptt_hang_time & 0x1F;
	c[4] = data->opts.tx_buffer_latency & 0x1F;
	break;
      case 0x2b:
	continue;
	// 0x2b	[31:24]	Predistortion subindex
	// 0x2b	[19:16]	Predistortion
	c[1] = data->opts.predistortion_subindex & 0xFF;
	c[2] = data->opts.predistortion & 0xF;
	break;
      case 0x3a:
	continue;
	// 0x3a	[0]	Reset HL2 on disconnect
	c[4] = data->opts.reset_hl2_on_disconnect & 1;
	break;
      case 0x3b:
	continue;
	// 0x3b	[31:24]	AD9866 SPI cookie, must be 0x06 to write
	// 0x3b	[20:16]	AD9866 SPI address
	// 0x3b	[7:0]	AD9866 SPI data
	break;
      case 0x3c:
	continue;
	// 0x3c	[31:24]	I2C1 cookie, must be 0x06 to write, 0x07 to read
	// 0x3c	[23]	I2C1 stop at end (0=continue, 1=stop)
	// 0x3c	[22:16]	I2C1 target chip address
	// 0x3c	[15:8]	I2C1 control
	// 0x3c	[7:0]	I2C1 data (only for write)
	break;
      case 0x3d:
	continue;
	// 0x3d	[31:24]	I2C2 cookie, must be 0x06 to write, 0x07 to read
	// 0x3d	[23]	I2C2 stop at end (0=continue, 1=stop)
	// 0x3d	[22:16]	I2C2 target chip address
	// 0x3d	[15:8]	I2C2 control
	// 0x3d	[7:0]	I2C2 data (only for write)
	break;
      case 0x3f:
	continue;
	// 0x3f	[31:0]	Error for responses
	break;
      default:
	// unassigned addr or out of range
	if (c0 > 0x3f) data->tx.index = 0;
	continue;
      }
      // fprintf(stderr, "_txiqscan seq %d, c0 0x%02x\n", data->tx.sequence-1, c0);
      break;
    }
  }
}

/*
** queue a udp rxiq packet from the HermesLite2 for later processing
*/
static int _rxiq(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 3)
    return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s %s udp_buffer", Tcl_GetString(objv[0]), Tcl_GetString(objv[1])));
  // udp packet in Tcl_Obj * byte array
  Tcl_Obj *udp = objv[2];

  // scan data
  _rxiqscan(data, udp);

  // queue for process
  if (packet_ring_buffer_can_write(&data->rx.rdy)) {
    packet_ring_buffer_write(&data->rx.rdy, objv[2]);
    Tcl_IncrRefCount(objv[2]);
    // fprintf(stderr, "_rxiq queued for _process\n");
  } else 
    return fw_error_obj(interp, Tcl_ObjPrintf("%s: no room to queue rxiq packet", Tcl_GetString(objv[0])));

  // drain rx.done, fill tx.rdy
  // fprintf(stderr, "_rxiq: drain rx.done, fill tx.rdy\n");
  while (packet_ring_buffer_can_read(&data->rx.done)) {
    Tcl_Obj *udp = packet_ring_buffer_read(&data->rx.done);
    // fprintf(stderr, "rxiq byte array shared %d, refcnt %d\n", Tcl_IsShared(udp), udp->refCount);
    if ( ! Tcl_IsShared(udp) && packet_ring_buffer_can_write(&data->tx.rdy)) {
      Tcl_InvalidateStringRep(udp);
      packet_ring_buffer_write(&data->tx.rdy, udp);
    } else
      Tcl_DecrRefCount(udp);
  }

  // if the tx buffer is near starvation, give it some more
  while (packet_ring_buffer_can_read(&data->tx.rdy) < 9)
    packet_ring_buffer_write(&data->tx.rdy, _packet_new());

  // return tx.done
  // fprintf(stderr, "_rxiq: return tx.done\n");
  if (packet_ring_buffer_can_read(&data->tx.done)) {
    // fprintf(stderr, "_rxiq: read tx.done\n");
    Tcl_Obj *udp = packet_ring_buffer_read(&data->tx.done);
    // fprintf(stderr, "_rxiq: got %p from tx.done\n", udp);
    // scan options
    _txiqscan(data, udp);
    // fprintf(stderr, "_rxiq: _txiqscan udp\n");
    Tcl_SetObjResult(interp, udp);
    // fprintf(stderr, "_rxiq: Tcl_SetObjResult(interp, udp);\n");
    Tcl_DecrRefCount(udp);
    // fprintf(stderr, "_rxiq: Tcl_DecrRefCount(udp);\n"); 
  }

  return TCL_OK;
}


static int _force(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s force", Tcl_GetString(objv[0])));
  Tcl_Obj *udp = _packet_new();
  _txiqscan(data, udp);
  return fw_success_obj(interp, udp);
}
  
static int _pending(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (argc != 2) return fw_error_obj(interp, Tcl_ObjPrintf("usage: %s pending", Tcl_GetString(objv[0])));
  Tcl_Obj *ret = Tcl_ObjPrintf("%d {%d %d {%s}} {%d %d {%s}}",
			       data->process,
			       packet_ring_buffer_can_read(&data->rx.rdy),
			       packet_ring_buffer_can_read(&data->rx.done),
			       // packet_ring_buffer_can_write(&data->rx.rdy),
			       // packet_ring_buffer_can_write(&data->rx.done),
			       // data->rx.sample, data->rx.underrun, data->rx.overrun,
			       data->rx.abort ? data->rx.abort : "", 
			       packet_ring_buffer_can_read(&data->tx.rdy),
			       packet_ring_buffer_can_read(&data->tx.done),
			       // packet_ring_buffer_can_write(&data->tx.rdy),
			       // packet_ring_buffer_can_write(&data->tx.done),
			       // data->tx.sample, data->tx.underrun, data->tx.overrun,
			       data->tx.abort ? data->tx.abort : ""
			       );
  data->rx.total_underrun += data->rx.underrun;
  data->rx.total_overrun += data->rx.overrun;
  data->tx.total_underrun += data->tx.underrun;
  data->tx.total_overrun += data->tx.overrun;
  data->rx.underrun = data->rx.overrun = 0;
  data->tx.underrun = data->tx.overrun = 0;
  data->rx.abort = data->tx.abort = NULL;
  return fw_success_obj(interp, ret);
}

static int _command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  _t *data = (_t *)clientData;
  if (framework_command(clientData, interp, argc, objv) != TCL_OK) return TCL_ERROR;
  void *p = _configure(data);
  if (p != data) return fw_error_str(interp, p);
  return TCL_OK;
}

static const fw_option_table_t _options[] = {
#include "framework_options.h"
  /* options set from discover response from radio */
  { "-gateware-version","int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.gateware_version), "gateware version" },
  { "-gateware-minor",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.gateware_minor), "gateware minor version." },
  { "-board-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.board_id), "board identifier." },
  { "-build-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.build_id), "board sub-identifier." },
  { "-n-hw-rx",		"int", "Int", "4", fw_option_int, 0, offsetof(_t, opts.n_hw_rx), "number of hardware receivers." },
  { "-wb-fmt",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.wb_fmt), "format of bandscope samples." },
  { "-mac-addr",	"str", "Str", "",   fw_option_obj, 0, offsetof(_t, opts.mac_addr), "radio mac address." },
  { "-mcp4662",		"str", "Str", "",   fw_option_obj, 0, offsetof(_t, opts.mcp4662), "mcp4662 configuration bytes." },
  { "-fixed-ip",	"str", "Str", "",   fw_option_obj, 0, offsetof(_t, opts.fixed_ip), "firmware assigned ip address." },
  { "-fixed-mac",	"str", "Str", "",   fw_option_obj, 0, offsetof(_t, opts.fixed_mac), "firmware assigned mac address bytes." },
  /* options set from iq packet responses from radio */
  { "-hw-dash",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_dash), "The hardware dash key value from the HermesLite." },
  { "-hw-dot",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_dot), "The hardware dot key value from the HermesLite." },
  { "-hw-ptt",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_ptt), "The hardware ptt value from the HermesLite." },
  { "-raw-overload",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.overload), "The ADC has clipped values in this frame." },
  { "-raw-recovery",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.recovery), "Buffer under/overlow recovery active." },
  { "-raw-tx-iq-fifo",	"int", "int", "0", fw_option_int, 0, offsetof(_t, opts.tx_iq_fifo), "TX IQ FIFO Count MSBs." },
  { "-serial",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.serial), "The Hermes software serial number." },
  { "-raw-temperature",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.temperature), "Raw ADC value for temperature sensor." },
  { "-raw-fwd-power",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.fwd_power), "Raw ADC value for forward power sensor." },
  { "-raw-rev-power",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.rev_power), "Raw ADC value for reverse power sensor." },
  { "-raw-pa-current",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pa_current), "Raw ADC value for power amplifier current sensor." },
  /* options set by user and relayed to radio in iq packets */
  { "-mox",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.mox), "enable transmitter." },
  { "-speed",		"int", "Int", "48000", fw_option_int, 0, offsetof(_t, opts.speed), 
			"Choose rate of RX IQ samples, may be 0, 1, 2, or 3, sample rate is 48000*2^speed." },
  { "-filters",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.filters), "Bits which enable filters on the N2ADR filter board." },
  { "-not-sync",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.not_sync), "Disable power supply sync." },
  { "-lna-db",		"int", "Int", "22", fw_option_int, 0, offsetof(_t, opts.lna_db), "Decibels of low noise amplifier on receive, from -12 to 48." },
  { "-n-rx",		"int", "Int", "1", fw_option_int, 0, offsetof(_t, opts.n_rx), "Number of receivers to implement, from 1 to 8 permitted." },
  { "-duplex",		"int", "Int", "1", fw_option_int, 0, offsetof(_t, opts.duplex), "Enable the transmitter frequency to vary independently of the receiver frequencies." },
  { "-f-tx",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_tx), "Transmitter NCO frequency" },
  { "-f-rx1",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[0]), "Receiver 1 NCO frequency." },
  { "-f-rx2",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[1]), "Receiver 2 NCO frequency." },
  { "-f-rx3",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[2]), "Receiver 3 NCO frequency." },
  { "-f-rx4",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[3]), "Receiver 4 NCO frequency." },
  { "-f-rx5",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[4]), "Receiver 5 NCO frequency." },
  { "-f-rx6",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[5]), "Receiver 6 NCO frequency." },
  { "-f-rx7",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[6]), "Receiver 7 NCO frequency." },
  { "-f-rx8",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[7]), "Receiver 8 NCO frequency." },
  { "-f-rx9",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[8]), "Receiver 9 NCO frequency." },
  { "-f-rx10",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[9]), "Receiver 10 NCO frequency." },
  { "-f-rx11",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[10]), "Receiver 11 NCO frequency." },
  { "-f-rx12",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx[11]), "Receiver 12 NCO frequency." },
  { "-level",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.level), "Transmitter power level, from 0 to 255." },
  { "-pa",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pa), "Enable power amplifier." },
  { "-low-pwr",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.low_pwr), "Disable T/R relay in low power operation." },
  { "-pure-signal",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pure_signal), "Enable Pure Signal operation. Not implemented." },
  { "-bias-adjust",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.bias_adjust), "Enable bias current adjustment for power amplifier." },
  { "-vna",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna), "Enable vector network analysis mode." },
  { "-vna-count",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna_count), "Number of frequencies sampled in VNA mode." },
  { "-vna-started",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna_started), "Start VNA mode." },
  /* option set by user and relayed to radio, later tranches */
  { "-vna-fixed-rx-gain","int","Int", "0", fw_option_int, 0, offsetof(_t, opts.vna_fixed_rx_gain), "Specify +/-6dB gain in VNA mode." },
  { "-alex-manual-mode","int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.alex_manual_mode), "." },
  { "-tune-request",    "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.tune_request), "." },
  { "-i2c-rx-filter",   "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.i2c_rx_filter), "." },
  { "-i2c-tx-filter",   "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.i2c_tx_filter), "." },
  { "-hermes-lite-lna", "int", "Int", "1", fw_option_int, 0, offsetof(_t, opts.hermes_lite_lna), "." },
  { "-cwx",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.cwx), "." },
  { "-cw-hang-time",    "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.cw_hang_time), "." },
  { "-tx-buffer-latency","int","Int", "10", fw_option_int, 0, offsetof(_t, opts.tx_buffer_latency), "." },
  { "-ptt-hang-time",   "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.ptt_hang_time), "." },
  { "-predistortion-subindex","int","Int","0",fw_option_int,0,offsetof(_t, opts.predistortion_subindex), "." },
  { "-predistortion",   "int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.predistortion), "." },
  { "-reset-hl2-on-disconnect","int","Int","0",fw_option_int,0,offsetof(_t, opts.reset_hl2_on_disconnect), "." },

  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "pending", _pending, "check the ringbuffer fills, etc." },
  { "rxiq", _rxiq, "rx iq buffers to jack exchanged for tx iq buffers from jack" },
  { "force", _force, "format packet of zero samples for transmission" },
  { NULL }
};

static const framework_t _templates[] = {
 {
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_1,			// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
 },{
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_2,			// process callback
  2, 4, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
 },{
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_3,			// process callback
  2, 6, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
 },{
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_4,			// process callback
  2, 8, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
#if 0
 },{
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_5,			// process callback
  2, 10, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
 },{
  _options,			// option table
  _subcommands,			// subcommand table
  _init,			// initialization function
  _command,			// command function
  _delete,			// delete function
  NULL,				// sample rate function
  _process_6,			// process callback
  2, 12, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2 software defined radio"
#endif
 }
};

/*
** This _factory accepts for -n-rx because -n-rx changes the number
** of outputs in the template and the _process callback.
*/
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  int n_rx = 1;
  int n_hw_rx = 4;
  for (int i = 2; i < argc; i += 2) {
    char *opt = Tcl_GetStringFromObj(objv[i], NULL);
    if (strcmp(opt, "-n-rx") == 0) {
      if (Tcl_GetIntFromObj(interp, objv[i+1], &n_rx) != TCL_OK)
	return fw_error_obj(interp, Tcl_ObjPrintf("invalid -n-rx value '%s'", Tcl_GetStringFromObj(objv[i+1], NULL)));
    } else if (strcmp(opt, "-n-hw-rx") == 0) {
      if (Tcl_GetIntFromObj(interp, objv[i+1], &n_hw_rx) != TCL_OK)
	return fw_error_obj(interp, Tcl_ObjPrintf("invalid -n-hw-rx value '%s'", Tcl_GetStringFromObj(objv[i+1], NULL)));
    }
  }
  if (n_rx < 1 || n_rx > n_hw_rx)
    return fw_error_obj(interp, Tcl_ObjPrintf("invalid -n-rx value '%d', must be from 1 to %d", n_rx, n_hw_rx));
  return framework_factory(clientData, interp, argc, objv, &_templates[n_rx-1], sizeof(_t));
}

int DLLEXPORT Hl_udp_jack_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::hl-udp-jack", "1.0.0", "sdrtcl::hl-udp-jack", _factory);
}
