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
** This component is built to take incoming IQ samples from the hermes lite 2,
** inject them into a running jack server, extract the transmit IQ samples
** from jack, and return them for transmission to the hermes lite.
**
** The component maintains the values of many options which are sent to and 
** received from the HermesLite2, the values may also be set or accessed by
** the Tcl script running the component.
**
** The incoming IQ samples are 24bits in memory, big-endian, but only the lowest
** 16bits are significant.  If there is more than one receiver running, then the
** receiver samples are interleaved.  There is also a monoaural microphone channel
** interleaved into the buffer as well, 16bits per sample, but it has no content,
** it simply occupies space. The incoming samples may arrive at 48, 96, 192, or 384
** ksps, which should match the jack sample rate. 
**
** The incoming samples arrive in the component instance as a 1032 byte UDP packet
** Tcl binary string, containing two 504 byte USB frames.
**
** We pass the entire UDP packet and use it as the sample buffer while we wait for
** the Jack process calls to consume the samples.  When the samples are consumed we
** release the packet.
**
** The outgoing IQ samples are 16bits, big-endian, interleaved with a stereo speaker
** channel, always at 48 ksps.  The outgoing samples are buffered into a 1032 byte
** UDP packet Tcl binary string.
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
** usage: %s rxiq rx_udp_buffer => {} or {tx_udp_buffer}
**
*/

#define FRAMEWORK_USES_JACK 1

#include "../dspmath/dspmath.h"
#include "framework.h"

typedef struct {
  /* operational options */
  int i_rx;			/* active receiver index */
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
  int speed;			/* Choose rate of RX IQ samples to be 48000, 96000, 192000, or 384000 samples per second. */
  int filters;			/* Bits which enable filters on the N2ADR filter board. */
  int not_sync;			/* Disable power supply sync. */
  int lna_db;			/* Decibels of low noise amplifier on receive, from -12 to 48. */
  int n_rx;			/* Number of receivers to implement, from 1 to 8 permitted. */
  int duplex;			/* Enable the transmitter frequency to vary independently of the receiver frequencies. */
  int f_tx;			/* Transmitter NCO frequency. */
  int f_rx1;			/* Receiver 1 NCO frequency. */
  int f_rx2;			/* Receiver 2 NCO frequency. */
  int f_rx3;			/* Receiver 3 NCO frequency. */
  int f_rx4;			/* Receiver 4 NCO frequency. */
  int f_rx5;			/* Receiver 5 NCO frequency. */
  int f_rx6;			/* Receiver 6 NCO frequency. */
  int f_rx7;			/* Receiver 7 NCO frequency. */
  int level;			/* Transmitter power level, from 0 to 255. */
  int pa;			/* Enable power amplifier. */
  int low_pwr;			/* Disable T/R relay in low power operation. */
  int pure_signal;		/* Enable Pure Signal operation. Not implemented. */
  int bias_adjust;		/* Enable bias current adjustment for power amplifier. Not implemented. */
  int vna;			/* Enable vector network analysis mode. Not implemented. */
  int vna_count;		/* Number of frequencies sampled in VNA mode. Not implemented. */
  int vna_started;		/* Start VNA mode. Not implemented. */
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
  packet_ring_buffer_t rdy;	/* Tcl_Obj's readied, ie tx empty, rx filled */
  packet_ring_buffer_t done;	/* Tcl_Obj's finished, ie tx filled, rx emptied */
  int overrun, underrun;	/* exception counters */
} packet_t;
  

typedef struct {
  framework_t fw;
  options_t opts;
  // is this tap running
  int started;
  // exception counters
  int rx_overrun, rx_underrun;
  int tx_overrun, tx_underrun;
  // packet management
  packet_t rx, tx;
} _t;

static inline void _packet_init(packet_t *pkt) {
  pkt->abort = NULL;
  pkt->udp = NULL;
  packet_ring_buffer_init(&pkt->rdy);
  packet_ring_buffer_init(&pkt->done);
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
      if (packet_ring_buffer_can_write(&pkt->done))
	packet_ring_buffer_write(&pkt->done, pkt->udp);
      else {
	pkt->abort = "packet_next: cannot write done";
	pkt->udp = NULL;
      }
    }
    if (packet_ring_buffer_can_read(&pkt->rdy)) {
      int n;
      pkt->udp = packet_ring_buffer_read(&pkt->rdy);
      pkt->buff = Tcl_GetByteArrayFromObj(pkt->udp, &n);
      pkt->usb = 0;
      pkt->i = 16;
      pkt->limit = 16 + 504;
    } else {
      pkt->abort = "packet_next: cannot read ready";
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
  // need to free any remaining byte arrays
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
static inline void _rxiqscan(_t *data, Tcl_Obj *udp) {
  int n;
  unsigned char *bytes = Tcl_GetByteArrayFromObj(udp, &n);
  for (int i = 8; i <= 520; i += 520-8) {
    unsigned char *c = bytes+i+3;
    // assert(c[-1] == 0x7f && c[-2] == 0x7f && c[-3] == 0x7f);
    //# scan control bytes into option values
    //# I suspect that key and ptt may be in more packets
    //# this switch statement looks suspicious
    switch (c[0]) {
    case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:      
      _grabkeyptt(data, c);
      data->opts.overflow = (c[1] & 1) != 0;
      data->opts.serial =  c[4];
      break;
    case 8: case 9: case 10: case 11: case 12: case 13: case 14: case 15:
      _grabkeyptt(data, c);
      data->opts.temperature = (c[1]<<8)|c[2];
      data->opts.fwd_power = (c[3]<<8)|c[4];
      break;
    case 16: case 17: case 18: case 19: case 20: case 21: case 22: case 23:
      _grabkeyptt(data, c);
      data->opts.rev_power = (c[1]<<8)|c[2];
      data->opts.pa_current = (c[3]<<8)|c[4];
    case 24: break;
    case 32: break;
    case 40: break;
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
#if 0
      method {tx conf} {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -mox {}
	    -speed { 
		set c1234(0) [expr {($c1234(0) & ~(3<<24)) | ([map-speed $val]<<24)}] 
		incr d(restart-requested)
	    }
	    -filters {
		set c1234(0) [expr {($c1234(0) & ~(127<<17)) | ($val<<17)}]
	    }
	    -not-sync {
		set c1234(0) [expr {($c1234(0) & ~(1<<12)) | ($val<<12)}]
	    }
	    -lna-db {
		set c1234(10) [expr {($c1234(10) & ~0x7F) | 0x40 | ($val+12)}]
	    }
	    -n-rx {
		set c1234(0) [expr {($c1234(0) & ~(7<<3)) | (($val-1)<<3)}]
		incr d(restart-requested)
	    }
	    -duplex {
		set c1234(0) [expr {($c1234(0) & ~(1<<2)) | ($val<<2)}]
	    }
	    -f-tx { set c1234(1) $val }
	    -f-rx1 { set c1234(2) $val }
	    -f-rx2 { set c1234(3) $val }
	    -f-rx3 { set c1234(4) $val }
	    -f-rx4 { set c1234(5) $val }
	    -f-rx5 { set c1234(6) $val }
	    -f-rx6 { set c1234(7) $val }
	    -f-rx7 { set c1234(8) $val }
	    -level {
		# c0 index 9, C1 entire
		set c1234(9) [expr {($c1234(9) & ~(0xFF<<24)) | ($val<<24)}]
	    }
	    -vna {
		# C0 index 9, C2 & 0x80
		set c1234(9) [expr {($c1234(9) & ~(1<<23)) | ($val<<23)}]
	    }
	    -pa {
		# C0 index 9, C2 & 0x08
		set c1234(9) [expr {($c1234(9) & ~(1<<19)) | ($val<<19)}]
	    }
	    -low-pwr {
		# C0 index 9, C2 & 0x04
		set c1234(9) [expr {($c1234(9) & ~(1<<18)) | ($val<<18)}]
	    }
	    -pure-signal {
		# C0 index 10, C2 & 0x40
		set c1234(10) [expr {($c1234(10) & ~(1<<22)) | ($val<<22)}]
	    }
	}
    }

    # generate the control bytes for header $index
    method {tx control} {} { 
	set index $d(tx-index)
	set d(tx-index) [expr {($d(tx-index)+1)%19}]
	return [binary format cI [expr {($index<<1)|$options(-mox)}] $c1234($index)]
    }
#endif
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
  { "-i-rx",		"int", "Int",    "-1", fw_option_int, 0, offsetof(_t, opts.i_rx), "active receiver index, obsolete?" },

  { "-code-version",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.code_version), "gateware version" },
  { "-board-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.board_id), "board identifier." },
  { "-mcp4662",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.mcp4662), "mcp4662 configuration bytes." },
  { "-n-hw-rx",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.n_hw_rx), "number of hardware receivers." },
  { "-wb-fmt",		"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.wb_fmt), "format of bandscope samples." },
  { "-build-id",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.build_id), "board sub-identifier." },
  { "-gateware-minor",	"int", "Int", "-1", fw_option_int, 0, offsetof(_t, opts.gateware_minor), "gateware minor version." },

  { "-mox",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.mox), "enable transmitter." },

  { "-speed",		"int", "Int", "48000", fw_option_int, 0, offsetof(_t, opts.speed), 
			"Choose rate of RX IQ samples to be 48000, 96000, 192000, or 384000 samples per second." },
  { "-filters",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.filters), "Bits which enable filters on the N2ADR filter board." },
  { "-not-sync",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.not_sync), "Disable power supply sync." },
  { "-lna-db",		"int", "Int", "20", fw_option_int, 0, offsetof(_t, opts.lna_db), "Decibels of low noise amplifier on receive, from -12 to 48." },
  { "-n-rx",		"int", "Int", "1", fw_option_int, 0, offsetof(_t, opts.n_rx), "Number of receivers to implement, from 1 to 8 permitted." },
  { "-duplex",		"int", "Int", "1", fw_option_int, 0, offsetof(_t, opts.duplex), "Enable the transmitter frequency to vary independently of the receiver frequencies." },
  { "-f-tx",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_tx), "Transmitter NCO frequency" },
  { "-f-rx1",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx1), "Receiver 1 NCO frequency." },
  { "-f-rx2",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx2), "Receiver 2 NCO frequency." },
  { "-f-rx3",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx3), "Receiver 3 NCO frequency." },
  { "-f-rx4",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx4), "Receiver 4 NCO frequency." },
  { "-f-rx5",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx5), "Receiver 5 NCO frequency." },
  { "-f-rx6",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx6), "Receiver 6 NCO frequency." },
  { "-f-rx7",		"int", "Int", "7012352", fw_option_int, 0, offsetof(_t, opts.f_rx7), "Receiver 7 NCO frequency." },
  { "-level",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.level), "Transmitter power level, from 0 to 255." },
  { "-pa",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pa), "Enable power amplifier." },
  { "-low-pwr",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.low_pwr), "Disable T/R relay in low power operation." },
  { "-pure-signal",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.pure_signal), "Enable Pure Signal operation. Not implemented." },
  { "-bias-adjust",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.bias_adjust), "Enable bias current adjustment for power amplifier. Not implemented." },
  { "-vna",		"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna), "Enable vector network analysis mode. Not implemented." },
  { "-vna-count",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna_count), "Number of frequencies sampled in VNA mode. Not implemented." },
  { "-vna-started",	"int", "Int", "0", fw_option_int, 0, offsetof(_t, opts.vna_started), "Start VNA mode. Not implemented." },

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
  "a component for servicing a hermes lite software defined radio"
};

/*
** This _factory should accept options for -speed and for -n-rx
** because -n-rx changes the number of outputs in the template
** and -n-rx and -speed changes the layout of received samples
** and -speed changes the decimation required for transmit samples
** so there needs to be a different _process callback for each combination
*/
static int _factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return framework_factory(clientData, interp, argc, objv, &_template, sizeof(_t));
}

int DLLEXPORT Hl2_udp_jack_Init(Tcl_Interp *interp) {
  fprintf(stderr, "Hl2_udp_jack_Init _process %p and outputs %d\n", _template.process, _template.n_outputs);
  return framework_init(interp, "sdrtcl::hl2-udp-jack", "1.0.0", "sdrtcl::hl2-udp-jack", _factory);
}
