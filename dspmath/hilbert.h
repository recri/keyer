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
#ifndef HILBERT_H
#define HILBERT_H

#include "dspmath.h"
#include "complex.h"

/*
** direct translation of dttsp/src/hilbert.c
** by Frank Brickle, AB2KT and Bob McGwier, N4HY
** included in total below.
**
** This hilbert transform takes an input stereo audio sample stream
** and produces a IQ complex sample stream.
*/

typedef struct {
  float c[12];
  float x1[12];
  float y1[12];
} hilbert_t;

typedef struct {
  float sample_rate;
} hilbert_options_t;

/// cf "Musical Engineer's Handbook" by Bernie Hutchins

static void *hilbert_init(hilbert_t *h, hilbert_options_t *opt) {
  static float pole[12] = {
    0.3609, 2.7412, 11.1573, 44.7581, 179.6242,  798.4578,
    1.2524, 5.5671, 22.3423, 89.6271, 364.7914, 2770.1114
  };
  for (int i = 0; i < 12; i++) {
    float u = pole[i] * pi * 15.0 * opt->sample_rate;
    h->c[i] = (u - 1.0) / (u + 1.0);
    h->x1[i] = h->y1[i] = 0.0;
  }
  return h;
}

static float _Complex hilbert_process(hilbert_t *h, const float _Complex in) {
  float xn1, xn2, yn1, yn2;

  xn1 = xn2 = (creal(in)+cimag(in))/2;

  for (int j = 0; j < 6; j++) {
    yn1 = h->c[j] * (xn1 - h->y1[j]) + h->x1[j];
    h->x1[j] = xn1;
    h->y1[j] = yn1;
    xn1 = yn1;
  }
    
  for (int j = 6; j < 12; j++) {
    yn2 = h->c[j] * (xn2 - h->y1[j]) + h->x1[j];
    h->x1[j] = xn2;
    h->y1[j] = yn2;
    xn2 = yn2;
  }
    
  return yn2 + yn1*I;
}

#endif
#if 0
/** 
* @file hilbert.c
* @brief Functions to implement Hilbert transformer 
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

#include <hilbert.h>

/// cf "Musical Engineer's Handbook" by Bernie Hutchins

PRIVATE REAL
pole[12] = {
   0.3609, 2.7412, 11.1573, 44.7581, 179.6242,  798.4578,
   1.2524, 5.5671, 22.3423, 89.6271, 364.7914, 2770.1114
};

/* -------------------------------------------------------------------------- */
/** @brief Create a new Hilbert transformer 
* 
* @param ibuf 
* @param obuf 
* @param rate 
* @return Hilbert
*/
/* ---------------------------------------------------------------------------- */
Hilbert
newHilbert(CXB ibuf, CXB obuf, REAL rate) {
  Hilbert h = (Hilbert) safealloc(1, sizeof(HilbertInfo), "Hilbert Transformer");
  h->size = CXBsize(ibuf);
  h->c  = newvec_REAL(12, "Hilbert Transformer c vector");
  h->x1 = newvec_REAL(12, "Hilbert Transformer x1 vector");
  h->y1 = newvec_REAL(12, "Hilbert Transformer y1 vector");
  {
    int i;
    for (i = 0; i < 12; i++) {
      REAL u = pole[i] * M_PI * 15.0 * rate;
      h->c[i] = (u - 1.0) / (u + 1.0);
      h->x1[i] = h->y1[i] = 0.0;
    }
  }
  h->buf.i = newCXB(h->size, CXBbase(ibuf), "Hilbert Transformer input buffer");
  h->buf.o = newCXB(h->size, CXBbase(obuf), "Hilbert Transformer output buffer");
  return h;
}

/* -------------------------------------------------------------------------- */
/** @brief Destroy a new Hilbert transformer 
* 
* @param h 
* @return void
*/
/* ---------------------------------------------------------------------------- */
void
delHilbert(Hilbert h) {
  if (h) {
    delvec_REAL(h->c);
    delvec_REAL(h->x1);
    delvec_REAL(h->y1);
    delCXB(h->buf.i);
    delCXB(h->buf.o);
    safefree((char *) h);
  }
}

/* -------------------------------------------------------------------------- */
/** @brief Run Hilbert transformer 
* 
* @param h 
* @return void
*/
/* ---------------------------------------------------------------------------- */
void
hilbert_transform(Hilbert h) {
  REAL xn1, xn2, yn1, yn2;
  int i;

  for (i = 0; i < h->size; i++) {
    int j;

    xn1 = xn2 = CXBreal(h->buf.i, i);

    for (j = 0; j < 6; j++) {
      yn1 = h->c[j] * (xn1 - h->y1[j]) + h->x1[j];
      h->x1[j] = xn1;
      h->y1[j] = yn1;
      xn1 = yn1;
    }
    
    for (j = 6; j < 12; j++) {
      yn2 = h->c[j] * (xn2 - h->y1[j]) + h->x1[j];
      h->x1[j] = xn2;
      h->y1[j] = yn2;
      xn2 = yn2;
    }
    
    CXBdata(h->buf.o, i) = Cmplx(yn2, yn1);
  }
}
 
/* -------------------------------------------------------------------------- */
/** @brief Run Hilbert simulation tranformer 
* 
* @param h 
* @return void
*/
/* ---------------------------------------------------------------------------- */
void
hilsim_transform(Hilsim h) {
  REAL *x = h->x,
       *y = h->y,
       *d = h->d;
  int i;
  
  for (i = 0; i < h->size; i++) {
    REAL xin = CXBreal(h->buf.i, i);
    
    x[0] = d[1] - xin;
    x[1] = d[0] - x[0] * 0.00196;
    x[2] = d[3] - x[1];
    x[3] = d[1] + x[2] * 0.737;
    
    d[1] = x[1];
    d[3] = x[3];
    
    y[0] = d[2] - xin;
    y[1] = d[0] + y[0] * 0.924;
    y[2] = d[4] - y[1];
    y[3] = d[2] + y[2] * 0.439;
    y[4] = d[5] - y[3];
    y[5] = d[4] - y[4] * 0.586;
    
    d[2] = y[1];
    d[4] = y[3];
    d[5] = y[5];
    
    d[0] = xin;
    
    CXBdata(h->buf.o, i) = Cmplx(x[3], y[5]);
  }
}

/* -------------------------------------------------------------------------- */
/** @brief Create new Hilbert simulator 
* 
* @param ibuf 
* @param obuf 
* @return Hilsim
*/
/* ---------------------------------------------------------------------------- */
Hilsim
newHilsim(CXB ibuf, CXB obuf) {
  Hilsim h = (Hilsim) safealloc(1, sizeof(HilsimInfo), "Simple Hilbert Transformer");
  memset((char *) h->x, 0, sizeof(h->x));
  memset((char *) h->y, 0, sizeof(h->y));
  memset((char *) h->d, 0, sizeof(h->d));
  h->buf.i = newCXB(h->size, CXBbase(ibuf), "Simple Hilbert Transformer input buffer");
  h->buf.o = newCXB(h->size, CXBbase(obuf), "Simple Hilbert Transformer output buffer");
  return h;
}
 
/* -------------------------------------------------------------------------- */
/** @brief Destroy Hilbert simulator 
* 
* @param h 
* @return void
*/
/* ---------------------------------------------------------------------------- */
void
delHilsim(Hilsim h) {
  if (h) {
    delCXB(h->buf.i);
    delCXB(h->buf.o);
    safefree((char *) h);
  }
}

/*
(defstruct (hilfil (:conc-name hilf-)) x y d)

(defun new-hilf ()
  (make-hilfil :x (make-array 4 :initial-element 0.0)
	       :y (make-array 6 :initial-element 0.0)
	       :d (make-array 6 :initial-element 0.0)))

(defun hilfilt (xin hilf)
  (let ((x (hilf-x hilf))
	(y (hilf-y hilf))
	(d (hilf-d hilf)))
    (setf (aref x 0) (- (aref d 1) xin)
	  (aref x 1) (- (aref d 0) (* (aref x 0) 0.00196))
	  (aref x 2) (- (aref d 3) (aref x 1))
	  (aref x 3) (+ (aref d 1) (* (aref x 2) 0.737))
	  (aref d 1) (aref x 1)
	  (aref d 3) (aref x 3)
	  (aref y 0) (- (aref d 2) xin)
	  (aref y 1) (+ (aref d 0) (* (aref y 0) 0.924))
	  (aref y 2) (- (aref d 4) (aref y 1))
	  (aref y 3) (+ (aref d 2) (* (aref y 2) 0.439))
	  (aref y 4) (- (aref d 5) (aref y 3))
	  (aref y 5) (- (aref d 4) (* (aref y 4) 0.586))
	  (aref d 5) (aref y 5)
	  (aref d 4) (aref y 3)
	  (aref d 2) (aref y 1)
	  (aref d 0) xin)
    (values (aref x 3) (aref y 5))))

 */  
#endif
