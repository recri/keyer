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
** the dttsp agc delays the signal by some number of samples,
** difficult to determine, while it figures out what the gain
** should be, even before these many reparameterizations
** get thrown in.
**
** a->sndx is the output index in a circular buffer,
** a->indx is the input index in the same buffer,
** a->fastindx is another index in the same buffer.
** the three indexes get initialized in a particular
** relationship when the agc is started, and they get
** incremented and reduced by buffer size on each
** iteration through the loop.
** then there are the codes from update which modifie
** rx[RL]->dttspagc.gen->sndx by itself. so there are
** bugs.
**
** really should track the agc level and run it through
** some tests to see what it does and doesn't do.
*/
#if 0				// dsp mailing lists
				// also quoted below
loop forever 
{ 
/* Voltage controlled amplifier is just a multiplier here */ 
yout=yin*iout 
/* error */ 
err=spoint-abs(yout) 
/* Integrate */ 
iout1=iout 
iout=iout1+gain*err } 
#endif
#if 0				// dttsp-cgran-r624/src/update.c
/* -------------------------------------------------------------------------- */
/** @brief private setfixedAGC 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setfixedAGC(int n, char **p) {
  REAL gain = atof(p[0]);
  if (n > 1) {
    int trx = atoi(p[1]);
    switch (trx) {
    case TX:
      tx->leveler.gen->gain.now = gain;
      break;
    case RX:
    default:
      rx[RL]->dttspagc.gen->gain.now = gain;
      break;
    }
  } else
    tx->leveler.gen->gain.now = rx[RL]->dttspagc.gen->gain.now = gain;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCCompression 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCCompression(int n, char **p) {
  REAL rxcompression = atof(p[0]);
  rx[RL]->dttspagc.gen->gain.top = pow(10.0, rxcompression * 0.05);
  return 0;
}

PRIVATE int
getRXAGC(int n, char **p) {
  sprintf(top->resp.buff,
	  "getRXAGC %d %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f\n",
	  rx[RL]->dttspagc.flag,
	  rx[RL]->dttspagc.gen->gain.bottom,
	  rx[RL]->dttspagc.gen->gain.fix,
	  rx[RL]->dttspagc.gen->gain.limit,
	  rx[RL]->dttspagc.gen->gain.top,
	  rx[RL]->dttspagc.gen->fastgain.bottom,
	  rx[RL]->dttspagc.gen->fastgain.fix,
	  rx[RL]->dttspagc.gen->fastgain.limit,
	  rx[RL]->dttspagc.gen->attack,
	  rx[RL]->dttspagc.gen->decay,
	  rx[RL]->dttspagc.gen->fastattack,
	  rx[RL]->dttspagc.gen->fastdecay,
	  rx[RL]->dttspagc.gen->fasthangtime,
	  rx[RL]->dttspagc.gen->hangthresh,
	  rx[RL]->dttspagc.gen->hangtime,
	  rx[RL]->dttspagc.gen->slope);
	  
  top->resp.size = strlen(top->resp.buff);
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXLevelerAttack 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXLevelerAttack(int n, char **p) {
  REAL tmp = atof(p[0]);
  tx->leveler.gen->attack = 1.0 - exp(-1000.0 / (tmp * uni->rate.sample));
  tx->leveler.gen->one_m_attack = exp(-1000.0 / (tmp * uni->rate.sample));
  tx->leveler.gen->sndx = (tx->leveler.gen->indx + (int) (0.003 * uni->rate.sample * tmp)) & tx->leveler.gen->mask;
  tx->leveler.gen->fastindx = (tx->leveler.gen->indx + FASTLEAD) & tx->leveler.gen->mask;
  tx->leveler.gen->fasthangtime = 0.1;	//wa6ahl: 100 ms
  return 0;
}

PRIVATE int
getTXLeveler(int n, char **p) {
  sprintf(top->resp.buff,
	  "getTXLeveler %d %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f\n",
	  tx->leveler.flag,
	  tx->leveler.gen->gain.bottom,
	  tx->leveler.gen->gain.fix,
	  tx->leveler.gen->gain.limit,
	  tx->leveler.gen->gain.top,
	  tx->leveler.gen->fastgain.bottom,
	  tx->leveler.gen->fastgain.fix,
	  tx->leveler.gen->fastgain.limit,
	  tx->leveler.gen->attack,
	  tx->leveler.gen->decay,
	  tx->leveler.gen->fastattack,
	  tx->leveler.gen->fastdecay,
	  tx->leveler.gen->fasthangtime,
	  tx->leveler.gen->hangthresh,
	  tx->leveler.gen->hangtime,
	  tx->leveler.gen->slope);
	  
  top->resp.size = strlen(top->resp.buff);
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXLevelerSt 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXLevelerSt(int n, char **p) {
  BOOLEAN tmp = atoi(p[0]);
  tx->leveler.flag = tmp;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXLevelerDecay 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXLevelerDecay(int n, char **p) {
  REAL tmp = atof(p[0]);
  tx->leveler.gen->decay = 1.0 - exp(-1000.0 / (tmp * uni->rate.sample));
  tx->leveler.gen->one_m_decay = exp(-1000.0 / (tmp * uni->rate.sample));
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXLevelerTop 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXLevelerTop(int n, char **p) {
  REAL top = atof(p[0]);
  tx->leveler.gen->gain.top = top;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXLevelerHang 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXLevelerHang(int n, char **p) {
  REAL hang = atof(p[0]);
  tx->leveler.gen->hangtime = 0.001 * hang;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGC 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGC(int n, char **p) {
  int setit = atoi(p[0]);
  rx[RL]->dttspagc.gen->mode = 1;
  rx[RL]->dttspagc.gen->attack = 1.0 - exp(-1000 / (2.0 * uni->rate.sample));
  rx[RL]->dttspagc.gen->one_m_attack = 1.0 - rx[RL]->dttspagc.gen->attack;
  rx[RL]->dttspagc.gen->hangindex = rx[RL]->dttspagc.gen->indx = 0;
  rx[RL]->dttspagc.gen->sndx = (int) (uni->rate.sample * 0.003f);
  rx[RL]->dttspagc.gen->fastindx = FASTLEAD;
  switch (setit) {
  case agcOFF:
    rx[RL]->dttspagc.gen->mode = agcOFF;
    rx[RL]->dttspagc.flag = TRUE;
    break;
  case agcSLOW:
    rx[RL]->dttspagc.gen->mode = agcSLOW;
    rx[RL]->dttspagc.gen->hangtime = 0.5;
    rx[RL]->dttspagc.gen->fasthangtime = 0.1;
    rx[RL]->dttspagc.gen->decay = 1.0 - exp(-1000 / (500.0 * uni->rate.sample));
    rx[RL]->dttspagc.gen->one_m_decay = 1.0 - rx[RL]->dttspagc.gen->decay;
    rx[RL]->dttspagc.flag = TRUE;
    break;
  case agcMED:
    rx[RL]->dttspagc.gen->mode = agcMED;
    rx[RL]->dttspagc.gen->hangtime = 0.25;
    rx[RL]->dttspagc.gen->fasthangtime = 0.1;
    rx[RL]->dttspagc.gen->decay = 1.0 - exp(-1000 / (250.0 * uni->rate.sample));
    rx[RL]->dttspagc.gen->one_m_decay = 1.0 - rx[RL]->dttspagc.gen->decay;
    rx[RL]->dttspagc.flag = TRUE;
    break;
  case agcFAST:
    rx[RL]->dttspagc.gen->mode = agcFAST;
    rx[RL]->dttspagc.gen->hangtime = 0.1;
    rx[RL]->dttspagc.gen->fasthangtime = 0.1;
    rx[RL]->dttspagc.gen->hangtime = 0.1;
    rx[RL]->dttspagc.gen->decay = 1.0 - exp(-1000 / (100.0 * uni->rate.sample));
    rx[RL]->dttspagc.gen->one_m_decay = 1.0 - rx[RL]->dttspagc.gen->decay;
    rx[RL]->dttspagc.flag = TRUE;
    break;
  case agcLONG:
    rx[RL]->dttspagc.gen->mode = agcLONG;
    rx[RL]->dttspagc.flag = TRUE;
    rx[RL]->dttspagc.gen->hangtime = 0.75;
    rx[RL]->dttspagc.gen->fasthangtime = 0.1;
    rx[RL]->dttspagc.gen->decay = 1.0 - exp(-0.5 / uni->rate.sample);
    rx[RL]->dttspagc.gen->one_m_decay = 1.0 - rx[RL]->dttspagc.gen->decay;
    break;
  }
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCAttack 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCAttack(int n, char **p) {
  REAL tmp = atof(p[0]);
  rx[RL]->dttspagc.gen->mode = 1;
  rx[RL]->dttspagc.gen->hangindex = rx[RL]->dttspagc.gen->indx = 0;
  rx[RL]->dttspagc.gen->fasthangtime = 0.1;
  rx[RL]->dttspagc.gen->fastindx = FASTLEAD;
  rx[RL]->dttspagc.gen->attack = 1.0 - exp(-1000.0 / (tmp * uni->rate.sample));
  rx[RL]->dttspagc.gen->one_m_attack = exp(-1000.0 / (tmp * uni->rate.sample));
  rx[RL]->dttspagc.gen->sndx = (int) (uni->rate.sample * tmp * 0.003);
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCDelay 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCDecay(int n, char **p) {
  REAL tmp = atof(p[0]);
  rx[RL]->dttspagc.gen->decay = 1.0 - exp(-1000.0 / (tmp * uni->rate.sample));
  rx[RL]->dttspagc.gen->one_m_decay = exp(-1000.0 / (tmp * uni->rate.sample));
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCHang 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCHang(int n, char **p) {
  REAL hang = atof(p[0]);
  rx[RL]->dttspagc.gen->hangtime = 0.001 * hang;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCSlope 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCSlope(int n, char **p) {
  REAL slope = atof(p[0]);
  rx[RL]->dttspagc.gen->slope = dB2lin(0.1 * slope);
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCHangThreshold 
* 
* @param h 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCHangThreshold(int h, char **p) {
  REAL hangthreshold = atof(p[0]);
  rx[RL]->dttspagc.gen->hangthresh = 0.01 * hangthreshold;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCLimit 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCLimit(int n, char **p) {
  REAL limit = atof(p[0]);
  rx[RL]->dttspagc.gen->gain.top = limit;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCTop 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCTop(int n, char **p) {
  REAL top = atof(p[0]);
  rx[RL]->dttspagc.gen->gain.top = top;
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setRXAGCFix 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setRXAGCFix(int n, char **p) {
  rx[RL]->dttspagc.gen->gain.fix = atof(p[0]);
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setfTXAGCFF 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXAGCFF(int n, char **p) {
  tx->spr.flag = atoi(p[0]);
  return 0;
}

/* -------------------------------------------------------------------------- */
/** @brief private setTXAGCFFCompression 
* 
* @param n 
* @param *p 
* @return int 
*/
/* ---------------------------------------------------------------------------- */
PRIVATE int
setTXAGCFFCompression(int n, char **p) {
  REAL txcompression = atof(p[0]);
  tx->spr.gen->MaxGain =
    (((0.0000401002 * txcompression) - 0.0032093390) * txcompression + 0.0612862687) * txcompression + 0.9759745718;
  return 0;
}

#endif
#if 0				// dttsp-cgran-r624/src/dttspagc.h
/* dttspagc.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY

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
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

The authors can be reached by email at

ab2kt@arrl.net
or
rwmcgwier@gmail.com

or by paper mail at

The DTTS Microwave Society
6 Kathleen Place
Bridgewater, NJ 08807
*/

#ifndef _dttspagc_h
#define _dttspagc_h

#include <fromsys.h>
#include <defs.h>
#include <banal.h>
#include <splitfields.h>
#include <datatypes.h>
#include <bufvec.h>

#define FASTLEAD 72

typedef enum _agcmode {
  agcOFF,
  agcLONG,
  agcSLOW,
  agcMED,
  agcFAST
} AGCMODE;

typedef
struct _dttspagc {
  struct {
    // interesting, fastgain isn't used?
    // it's set in update, but never ref'ed in dttspagc
    REAL bottom,
         fastnow,
         fix,
         limit,
         now,
         old,			// not used
         raw,
         top;
  } gain, fastgain;
  int fasthang,
      fastindx,
      hangindex,
      indx,
      mask,
      mode,
      sndx;
  REAL attack,
       decay,
       fastattack,
       fastdecay,
       fasthangtime,
       hangthresh,
       hangtime,
       one_m_attack,
       one_m_decay,
       one_m_fastattack,
       one_m_fastdecay,
       samprate,
       slope;
  COMPLEX *circ;
  CXB buff;
  char tag[4];
} dttspagc, *DTTSPAGC;

extern void DttSPAgc(DTTSPAGC a, int tick);
extern DTTSPAGC newDttSPAgc(AGCMODE mode,
			    COMPLEX *Vec,
			    int BufSize,
			    REAL Limit,
			    REAL attack,
			    REAL decay,
			    REAL slope,
			    REAL hangtime,
			    REAL samprate,
			    REAL MaxGain,
			    REAL MinGain,
			    REAL Curgain,
			    char *tag);
extern void delDttSPAgc(DTTSPAGC a);

#endif
#endif
#if 0				// dttsp-cgran-r624/src/dttspagc.c
/** 
* @file dttspagc.c
* @brief Functions to implement automatic gain control  
* @author Frank Brickle, AB2KT and Bob McGwier, N4HY

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
Doxygen comments added by Dave Larsen, KV0S

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
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

The authors can be reached by email at

ab2kt@arrl.net
or
rwmcgwier@gmail.com

or by paper mail at

The DTTS Microwave Society
6 Kathleen Place
Bridgewater, NJ 08807
*/

#include <dttspagc.h>

#ifdef min
#undef min
#endif

/* -------------------------------------------------------------------------- */
/** @brief min 
* 
* @param a 
* @param b 
*/
/* ---------------------------------------------------------------------------- */
static INLINE REAL
min(REAL a, REAL b) { return a < b ? a : b; }

#ifdef max
#undef max
#endif

/* -------------------------------------------------------------------------- */
/** @brief 
* 
* @param a 
* @param b 
*/
/* ---------------------------------------------------------------------------- */
static INLINE REAL
max(REAL a, REAL b) { return a > b ? a : b; }

/* -------------------------------------------------------------------------- */
/** @brief DttSPAgc 
* 
* @param mode 
* @param Vec 
* @param BufSize 
* @param Limit 
* @param attack 
* @param decay 
* @param slope 
* @param hangtime 
* @param samprate 
* @param MaxGain 
* @param MinGain 
* @param CurGain 
* @param tag 
*/
/* ---------------------------------------------------------------------------- */
DTTSPAGC
newDttSPAgc(AGCMODE mode,
	    COMPLEX *Vec,
	    int BufSize,
	    REAL Limit,
	    REAL attack,
	    REAL decay,
	    REAL slope,
	    REAL hangtime,
	    REAL samprate,
	    REAL MaxGain,
	    REAL MinGain,
	    REAL CurGain,
	    char *tag) {
  DTTSPAGC a;

  a = (DTTSPAGC) safealloc(1, sizeof(dttspagc), tag);
  a->mode = mode;

  a->attack = (REAL) (1.0 - exp(-1000.0 / (attack * samprate)));
  a->one_m_attack = (REAL) exp(-1000.0 / (attack * samprate));

  a->decay = (REAL) (1.0 - exp(-1000.0 / (decay * samprate)));
  a->one_m_decay = (REAL) exp(-1000.0 / (decay * samprate));

  a->fastattack = (REAL) (1.0 - exp(-1000.0 / (0.2 * samprate)));
  a->one_m_fastattack = (REAL) exp(-1000.0 / (0.2 * samprate));

  a->fastdecay = (REAL) (1.0 - exp(-1000.0 / (3.0 * samprate)));
  a->one_m_fastdecay = (REAL) exp(-1000.0 / (3.0 * samprate));

  strcpy(a->tag, tag);
  a->mask = 2 * BufSize;

  a->hangindex = a->indx = 0;
  a->hangtime = hangtime * 0.001;
  a->hangthresh = 0.0;
  a->sndx = (int) (samprate * attack * 0.003);
  a->fastindx = FASTLEAD;
  a->gain.fix = 10.0;

  a->slope = slope;
  a->gain.top = MaxGain;
  a->hangthresh = a->gain.bottom = MinGain;
  a->gain.fastnow = a->gain.old = a->gain.now = CurGain;

  a->gain.limit = Limit;

  a->buff = newCXB(BufSize, Vec, "agc in buffer");
  a->circ = newvec_COMPLEX(a->mask, "circular agc buffer");
  a->mask -= 1;

  a->fasthang = 0;
  a->fasthangtime = 48 * 0.001;
  a->samprate = samprate;

  return a;
}

/* -------------------------------------------------------------------------- */
/** @brief DttSPAgc 
* 
* @param a 
* @param tick 
*/
/* ---------------------------------------------------------------------------- */
void DttSPAgc(DTTSPAGC a, int tick) {
  int i;
  int hangtime = (int) (a->samprate * a->hangtime);
  int fasthangtime = (int) (a->samprate * a->fasthangtime);
  REAL hangthresh;

  // compute these on every buffer?  really?
  if (a->hangthresh > 0)
    hangthresh = a->gain.top * a->hangthresh + a->gain.bottom * (REAL) (1.0 - a->hangthresh);
  else
    hangthresh = 0.0;

  // oh, and conditionally implement a fixed agc on every buffer
  // this is the only place mode gets touched in the code
  if (a->mode == 0) {
#ifdef __SSE3__
    SSEScaleCOMPLEX(a->buff, a->buff, a->gain.fix, CXBhave(a->buff));
#else
    for (i = 0; i < CXBhave(a->buff); i++)
      CXBdata(a->buff, i) = Cscl(CXBdata(a->buff, i), a->gain.fix);
#endif
    return;
  }

  // for each input sample
  for (i = 0; i < CXBhave(a->buff); i++) {
    REAL tmp;

    // store the input sample into the ring buffer
    a->circ[a->indx] = CXBdata(a->buff, i);

    // this section almost computes a new value for a->gain.now
    // it doesn't if hangindex <= hangtime
    tmp = 1.1 * Cmag(a->circ[a->indx]);

    if (tmp != 0.0)
      tmp = a->gain.limit / tmp;	// if not zero sample, calculate gain
    else
      tmp = a->gain.now;		// update. If zero, then use old gain

    // start the hang
    if (tmp < hangthresh)
      a->hangindex = hangtime;

    if (tmp >= a->gain.now) {
      a->gain.raw = a->one_m_decay * a->gain.now + a->decay * tmp;
      if (a->hangindex++ > hangtime)
	a->gain.now = a->one_m_decay * a->gain.now + a->decay * min(a->gain.top, tmp);
    } else {
      a->hangindex = 0;
      a->gain.raw = a->one_m_attack * a->gain.now + a->attack * tmp;
      a->gain.now = a->one_m_attack * a->gain.now + a->attack * max(tmp, a->gain.bottom);
    }

    // and this section almost computes a new value for a->gain.fastnow
    // it doesn't if fasthang <= fasthangtime
    tmp = 1.2f * Cmag(a->circ[a->fastindx]);
    if (tmp != 0.0)
      tmp = a->gain.limit / tmp;
    else
      tmp = a->gain.fastnow;

    if (tmp > a->gain.fastnow) {
      if (a->fasthang++ > fasthangtime) {
	a->gain.fastnow = min(a->one_m_fastdecay * a->gain.fastnow + a->fastdecay * min(a->gain.top, tmp), a->gain.top);
      }
    } else {
      a->fasthang = 0;
      a->gain.fastnow = max(a->one_m_fastattack * a->gain.fastnow + a->fastattack * max(tmp, a->gain.bottom), a->gain.bottom);
    }

    // threshold gain.fastnow to top and bottom
    a->gain.fastnow = max(min(a->gain.fastnow, a->gain.top), a->gain.bottom);

    // threshold gain.now to top and bottom
    a->gain.now = max(min(a->gain.now, a->gain.top), a->gain.bottom);

    // scale the output sample by the minimum
    CXBdata(a->buff, i) = Cscl(a->circ[a->sndx], min(a->gain.fastnow, min(a->slope * a->gain.now, a->gain.top)));

    // advance the ringbuffer indexes
    a->indx = (a->indx + a->mask) & a->mask;
    a->sndx = (a->sndx + a->mask) & a->mask;
    a->fastindx = (a->fastindx + a->mask) & a->mask;
  }
}

/* -------------------------------------------------------------------------- */
/** @brief delDttSPAgc 
* 
* @param a 
*/
/* ---------------------------------------------------------------------------- */
void
delDttSPAgc(DTTSPAGC a) {
  if (a) {
    delCXB(a->buff);
    delvec_COMPLEX(a->circ);
    safefree((char *) a);
  }
}

#if 0
gain = 1e-3;
spoint = 1.0;
for (;;) {
  /* Voltage controlled amplifier is just a multiplier here */
  yout = yin * iout;

  /* error */
  err = spoint - abs(yout);

  /* Integrate */
  iout1 = iout;
  iout = iout1 + gain * err;
}

if (signal_too_big())
  decrease_gain_quickly();
else if (signal_below_threshold() && gain_not_too_high_already())
  increase_gain_slowly();

#endif

#endif 

#include "sdrkit.h"

/*
** create an automatic gain control module
** many scalar parameters
*/
typedef struct {
} agc_params_t;

typedef struct {
  SDRKIT_T_COMMON;
  agc_params_t *current, p[2];
} agc_t;
  
static void agc_init(void *arg) {
  agc_t *data = (agc_t *)arg;
  data->current = data->p+0;
}

static int agc_process(jack_nframes_t nframes, void *arg) {
}

static int agc_command(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
}

static int agc_factory(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  return sdrkit_factory(clientData, interp, argc, objv, 2, 2, 0, 0, agc_command, agc_process, sizeof(agc_t), agc_init, NULL);
}

// the initialization function which installs the adapter factory
int DLLEXPORT Sdrkit_agc_Init(Tcl_Interp *interp) {
  return sdrkit_init(interp, "sdrkit", "1.0.0", "sdrkit::agc", agc_factory);
}
