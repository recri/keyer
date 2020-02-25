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

#include "../dspmath/dspmath.h"
#include "framework.h"

typedef struct {
  /* discovered options */
  int code_version;		/* gateware version */
  int board_id;			/* board identifier */
  int mcp4662;			/* mcp4662 configuration bytes */
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
  int overflow;			/* The ADC has clipped values in this frame. */
  int serial;			/* The Hermes software serial number. */
  int temperature;		/* Raw ADC value for temperature sensor. */
  int fwd_power;		/* Raw ADC value for forward power sensor. */
  int rev_power;		/* Raw ADC value for reverse power sensor. */
  int pa_current;		/* Raw ADC value for power amplifier current sensor. */
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
** ring buffers for shuffling byte arrays between threads
*/
#define PACKET_RING_SIZE 8	/* must be power of two */
/* #assert(PACKET_RING_SIZE > 1) */
/* #assert((PACKET_RING_SIZE & (PACKET_RING_SIZE-1)) == 0) */
typedef struct {
  Tcl_Obj *ring[PACKET_RING_SIZE];
  unsigned short rdptr, wrptr;
} packet_ring_buffer_t;
static inline void packet_ring_buffer_init(packet_ring_buffer_t *rb) { rb->rdptr = rb->wrptr = 0; }
static inline int packet_ring_buffer_can_read(packet_ring_buffer_t *rb) { return rb->wrptr - rb->rdptr; }
static inline Tcl_Obj *packet_ring_buffer_read(packet_ring_buffer_t *rb) { return rb->ring[rb->rdptr++&(PACKET_RING_SIZE-1)]; }
static inline int packet_ring_buffer_can_write(packet_ring_buffer_t *rb) { return PACKET_RING_SIZE-packet_ring_buffer_can_read(rb); }
static inline void packet_ring_buffer_write(packet_ring_buffer_t *rb, Tcl_Obj *obj) { rb->ring[rb->wrptr++&(PACKET_RING_SIZE-1)] = obj; }

/*
** current active packet for tx or rx samples
*/
typedef struct {
  char *abort;			/* signal something awful happened */
  Tcl_Obj *udp;			/* current udp packet byte array object */
  unsigned char *buff;		/* start of udp packet byte array */
  int i;			/* read/write offset into byte array */
  int limit;			/* sizeof current read/write area */
  int usb;			/* which usb frame being read/written */
  packet_ring_buffer_t rdy;	/* Tcl_Obj's ready to process, ie tx empty, rx filled */
  packet_ring_buffer_t done;	/* Tcl_Obj's finished processing, ie tx filled, rx emptied */
  unsigned overrun;		/* exception counters */
  unsigned underrun;
  unsigned outofseq;
  unsigned sequence;		/* packet sequence and header index counters */
  unsigned index;		
} packet_t;

typedef struct {
  framework_t fw;
  options_t opts;
  // is this tap running
  int started;
  // packet management
  packet_t rx, tx;
} _t;

static inline void _packet_init(packet_t *pkt) {
  pkt->abort = NULL;
  pkt->udp = NULL;
  packet_ring_buffer_init(&pkt->rdy);
  packet_ring_buffer_init(&pkt->done);
  pkt->overrun = 0;
  pkt->underrun = 0;
  pkt->sequence = 0;
  pkt->index = 0;
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
	Tcl_DecrRefCount(pkt->udp);
	pkt->udp = NULL;
      }
    }
    // assert(pkt->udp == NULL);
    if (packet_ring_buffer_can_read(&pkt->rdy)) {
      int n;
      pkt->udp = packet_ring_buffer_read(&pkt->rdy);
      pkt->buff = Tcl_GetByteArrayFromObj(pkt->udp, &n);
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
  _packet_init(&data->rx);
  _packet_init(&data->tx);
  // should toss a packet into the tx queue
  return arg;
}

static void _delete(void *arg) {
  _t *data = (_t *)arg;
  data->started = 0;
  _packet_delete(&data->rx);
  _packet_delete(&data->tx);
}

/*
** handle transmit samples, at higher sample rates decimate to 48k
*/
static inline void _txiq_x48(_t *data, int i, float *ptri, float *ptrq) {
  if (data->tx.udp == NULL) {
    data->tx.overrun += 1;
  } else {
    short s[2] = { *ptri * 32767, *ptrq * 32767 };
    data->tx.buff[data->tx.i++] = 0;	/* Left audio channel high byte */
    data->tx.buff[data->tx.i++] = 0;	/* Left audio channel low byte */
    data->tx.buff[data->tx.i++] = 0;	/* Right audio channel high byte */
    data->tx.buff[data->tx.i++] = 0;	/* Right audio channel low byte */
    data->tx.buff[data->tx.i++] = s[0]>>8;	/* I sample high byte */
    data->tx.buff[data->tx.i++] = s[0];	/* I sample low byte */
    data->tx.buff[data->tx.i++] = s[1]>>8;	/* Q sample high byte */
    data->tx.buff[data->tx.i++] = s[1];	/* Q sample low byte */
    if (data->tx.i + 8 > data->tx.limit) {
      _packet_next(&data->tx);
    }
  }
}
static inline void _txiq_x96(_t *data, int i, float *ptri, float *ptrq) {
  if ((i & 1) == 0) _txiq_x48(data, i, ptri, ptrq);
}
static inline void _txiq_x192(_t *data, int i, float *ptri, float *ptrq) {
  if ((i & 3) == 0) _txiq_x48(data, i, ptri, ptrq);
}
static inline void _txiq_x384(_t *data, int i, float *ptri, float *ptrq) {
  if ((i & 7) == 0) _txiq_x48(data, i, ptri, ptrq);
}

/*
** handle receive samples
*/
static inline  void _rxiq_1x(_t *data, int i, float *ptri, float *ptrq) {
  // convert and copy input samples into jack buffer
  // const int stride = data->opts.n_rx * 6 + 2; /* size of one frame of receiver data */
  const char *input = data->rx.buff+data->rx.i;
  *ptri = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8)) >> 8) / (float)0x7ff;
  *ptrq = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8)) >> 8) / (float)0x7ff;
  data->rx.i += 8;
  if (data->rx.i + 8 > data->rx.limit) _packet_next(&data->rx);
}

static inline  void _rxiq_2x(_t *data, int i, float *ptri, float *ptrq, float *ptri1, float *ptrq1) {
  const char *input = data->rx.buff+data->rx.i;
  *ptri = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8)) >> 8) / (float)0x7ff;
  *ptrq = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8)) >> 8) / (float)0x7ff;
  *ptri1 = (((input[6+0]<<24) | (input[6+1]<<16) | (input[6+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq1 = (((input[6+3]<<24) | (input[6+4]<<16) | (input[6+5]<<8)) >> 8) / (float)0x7ff;
  data->rx.i += 14;
  if (data->rx.i + 14 > data->rx.limit) _packet_next(&data->rx);
}

static inline  void _rxiq_3x(_t *data, int i, float *ptri, float *ptrq, float *ptri1, float *ptrq1, float *ptri2, float *ptrq2) {
  const char *input = data->rx.buff+data->rx.i;
  *ptri = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8)) >> 8) / (float)0x7ff;
  *ptrq = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8)) >> 8) / (float)0x7ff;
  *ptri1 = (((input[6+0]<<24) | (input[6+1]<<16) | (input[6+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq1 = (((input[6+3]<<24) | (input[6+4]<<16) | (input[6+5]<<8)) >> 8) / (float)0x7ff;
  *ptri2 = (((input[12+0]<<24) | (input[12+1]<<16) | (input[12+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq2 = (((input[12+3]<<24) | (input[12+4]<<16) | (input[12+5]<<8)) >> 8) / (float)0x7ff;
  data->rx.i += 20;
  if (data->rx.i + 20 > data->rx.limit) _packet_next(&data->rx);
}

static inline  void _rxiq_4x(_t *data, int i, float *ptri, float *ptrq, float *ptri1, float *ptrq1, float *ptri2, float *ptrq2, float *ptri3, float *ptrq3) {
  const char *input = data->rx.buff+data->rx.i;
  *ptri = (((input[0]<<24) | (input[1]<<16) | (input[2]<<8)) >> 8) / (float)0x7ff;
  *ptrq = (((input[3]<<24) | (input[4]<<16) | (input[5]<<8)) >> 8) / (float)0x7ff;
  *ptri1 = (((input[6+0]<<24) | (input[6+1]<<16) | (input[6+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq1 = (((input[6+3]<<24) | (input[6+4]<<16) | (input[6+5]<<8)) >> 8) / (float)0x7ff;
  *ptri2 = (((input[12+0]<<24) | (input[12+1]<<16) | (input[12+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq2 = (((input[12+3]<<24) | (input[12+4]<<16) | (input[12+5]<<8)) >> 8) / (float)0x7ff;
  *ptri3 = (((input[18+0]<<24) | (input[18+1]<<16) | (input[18+2]<<8)) >> 8) / (float)0x7ff;
  *ptrq3 = (((input[18+3]<<24) | (input[18+4]<<16) | (input[18+5]<<8)) >> 8) / (float)0x7ff;
  data->rx.i += 26;
  if (data->rx.i + 26 > data->rx.limit) _packet_next(&data->rx);
}

/* process callback for 1 rx Hz */
static int _process_1x48(jack_nframes_t nframes, void *arg) {
  _t *data = (_t *)arg;
  if (data->started) {
    float *in0 = jack_port_get_buffer(framework_input(arg,0), nframes); /* tx i stream, input from jack, outgoing to radio */
    float *in1 = jack_port_get_buffer(framework_input(arg,1), nframes); /* tx q stream, input from jack, outgoing to radio */
    float *out0 = jack_port_get_buffer(framework_output(arg,0), nframes); /* rx i stream, incoming from radio, output to jack */
    float *out1 = jack_port_get_buffer(framework_output(arg,1), nframes); /* rx q stream, incoming from radio, output to jack */
    for (int i = 0; i < nframes; i += 1) {
      _txiq_x48(data, i, in0++, in1++);
      _rxiq_1x(data, i, out0++, out1++);
    }
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
  unsigned char *bytes = Tcl_GetByteArrayFromObj(udp, &n);
  // bytes[0:2] == sync 0xeffe01
  // bytes[3] == end point == 6 for rx iq data
  // bytes[4:7] == sequence number
  unsigned sync = _loadu(bytes+0);
  unsigned seq = _loadu(bytes+4);
  fprintf(stderr, "sync %x seq %x\n", sync, seq);
  for (int i = 8; i <= 520; i += 520-8) {
    unsigned char *c = bytes+i+3;
    // assert(c[-1] == 0x7f && c[-2] == 0x7f && c[-3] == 0x7f);
    //# scan control bytes into option values
    //# I suspect that key and ptt may be in more packets
    //# this switch statement looks suspicious
    switch (c[0]) {
    case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:      
      data->rx.index = 0;
      _grabkeyptt(data, c);
      data->opts.overflow = (c[1] & 1) != 0;
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
}

/*
** translate hl2_udp_jack options into command bytes in udp packets.
*/
static inline void _txiqscan(_t *data, Tcl_Obj *udp) {
  int n;
  unsigned char *bytes = Tcl_GetByteArrayFromObj(udp, &n);
  for (int i = 8; i <= 520; i += 520-8) {
    unsigned char *c = bytes+i+3;
    // assert(c[-1] == 0x7f && c[-2] == 0x7f && c[-3] == 0x7f);
    while (1) {
      unsigned c0 = data->tx.index++;
      c[0] = (c0 << 1) | data->opts.mox; // set the addr and the mox bit
      c[1] = c[2] = c[3] = c[4] = 0;	 // clear out any leftover rx bits
      switch (c0) {
      case 0x0:
	// 0x00	[25:24]	Speed (00=48kHz, 01=96kHz, 10=192kHz, 11=384kHz)
	// -speed { set c1234(0) [expr {($c1234(0) & ~(3<<24)) | ([map-speed $val]<<24)}] } # restart requested
	c[1] = data->opts.speed & 3;
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
	c[4] = ((data->opts.n_rx & 7) << 3) | ((data->opts.duplex & 1) << 2);
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
	if (data->opts.n_rx < rxn) continue;
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
	if (data->opts.n_rx < rxn) continue;
	_storeu(c+1, data->opts.f_rx[rxn-1]);
	break;
      }
      case 0x17:
	// 0x17	[4:0]	TX buffer latency in ms, default is 10ms
	// 0x17	[12:8]	PTT hang time, default is 4ms
	c[3] = data->opts.ptt_hang_time & 0x1F;
	c[4] = data->opts.tx_buffer_latency & 0x1F;
	break;
      case 0x2b:
	// 0x2b	[31:24]	Predistortion subindex
	// 0x2b	[19:16]	Predistortion
	c[1] = data->opts.predistortion_subindex & 0xFF;
	c[2] = data->opts.predistortion & 0xF;
	break;
      case 0x3a:
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
  if ( ! data->started)
    return fw_error_obj(interp, Tcl_ObjPrintf("hl2-jack %s is not running", Tcl_GetString(objv[0])));
  else {
    // udp packet in Tcl_Obj *
    Tcl_Obj *udp = objv[2];
    // scan data
    _rxiqscan(data, udp);
    // queue for process
    if (packet_ring_buffer_can_write(&data->rx.rdy)) {
      packet_ring_buffer_write(&data->rx.rdy, objv[2]);
      Tcl_IncrRefCount(objv[2]);
    } else
      return fw_error_obj(interp, Tcl_ObjPrintf("%s: no room to queue rxiq packet", Tcl_GetString(objv[0])));
  }
  while (packet_ring_buffer_can_read(&data->rx.done)) {
    Tcl_Obj *udp = packet_ring_buffer_read(&data->rx.done);
    fprintf(stderr, "rxiq byte array shared %d, refcnt %d\n", Tcl_IsShared(udp), udp->refCount);
    if (packet_ring_buffer_can_write(&data->tx.rdy))
      packet_ring_buffer_write(&data->tx.rdy, udp);
    else
      Tcl_DecrRefCount(udp);
  }
  if (packet_ring_buffer_can_read(&data->tx.done)) {
    Tcl_Obj *udp = packet_ring_buffer_read(&data->tx.done);
    // scan options
    _txiqscan(data, udp);
    Tcl_SetObjResult(interp, udp);
    Tcl_DecrRefCount(udp);
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
  return
    (argc != 2) ?
    fw_error_obj(interp, Tcl_ObjPrintf("usage: %s pending", Tcl_GetString(objv[0]))) : 
    fw_success_obj(interp, Tcl_ObjPrintf("%d %d %d %d",
					 packet_ring_buffer_can_read(&data->rx.rdy),
					 packet_ring_buffer_can_read(&data->rx.done),
					 packet_ring_buffer_can_read(&data->tx.rdy),
					 packet_ring_buffer_can_read(&data->tx.done)));
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

  { "-code-version",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.code_version), "gateware version" },
  { "-board-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.board_id), "board identifier." },
  { "-mcp4662",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.mcp4662), "mcp4662 configuration bytes." },
  { "-n-hw-rx",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.n_hw_rx), "number of hardware receivers." },
  { "-wb-fmt",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.wb_fmt), "format of bandscope samples." },
  { "-build-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.build_id), "board sub-identifier." },
  { "-gateware-minor",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.gateware_minor), "gateware minor version." },

  { "-mox",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.mox), "enable transmitter." },

  { "-speed",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.speed), 
			"Choose rate of RX IQ samples, may be 0, 1, 2, or 3, sample rate is 48000*2^speed." },
  { "-filters",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.filters), "Bits which enable filters on the N2ADR filter board." },
  { "-not-sync",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.not_sync), "Disable power supply sync." },
  { "-lna-db",		"int", "Int", "38", fw_option_int, 0, offsetof(_t, opts.lna_db), "Decibels of low noise amplifier on receive, from -12 to 48." },
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

  { "-hw-dash",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_dash), "The hardware dash key value from the HermesLite." },
  { "-hw-dot",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_dot), "The hardware dot key value from the HermesLite." },
  { "-hw-ptt",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.hw_ptt), "The hardware ptt value from the HermesLite." },
  { "-overflow",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.overflow), "The ADC has clipped values in this frame." },
  { "-serial",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.serial), "The Hermes software serial number." },
  { "-temperature",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.temperature), "Raw ADC value for temperature sensor." },
  { "-fwd-power",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.fwd_power), "Raw ADC value for forward power sensor." },
  { "-rev-power",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.rev_power), "Raw ADC value for reverse power sensor." },
  { "-pa-current",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pa_current), "Raw ADC value for power amplifier current sensor." },

  { NULL }
};

static const fw_subcommand_table_t _subcommands[] = {
#include "framework_subcommands.h"
  { "pending", _pending, "check the ringbuffer fills" },
  { "rxiq", _rxiq, "rx iq buffers to jack exchanged for tx iq buffers from jack" },
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
  _process_1x48,		// process callback
  2, 2, 0, 0, 0,		// inputs,outputs,midi_inputs,midi_outputs,midi_buffers
  "a component for servicing a HermesLite2f software defined radio"
};

/*
** This _factory should accept options for -speed and for -n-rx
** because -n-rx changes the number of outputs in the template
** and -n-rx and -speed changes the layout of received samples
** and -speed changes the decimation required for transmit samples
** so there needs to be a different _process callback for each combination
*/
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  fprintf(stderr, "Hl_udp_jack_Init _process %p and outputs %d\n", _template.process, _template.n_outputs);
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Hl_udp_jack_Init(Tcl_Interp *interp) {
  return framework_init(interp, "sdrtcl::hl-udp-jack", "1.0.0", "sdrtcl::hl-udp-jack", _factory);
}
