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

#ifndef IAMBIC_DTTSP_H
#define IAMBIC_DTTSP_H

/*
** This is the core of iambic-keyer.c from dttsp.
**
** The code in this file is derived from routines originally written by
** Pierre-Philippe Coupard for his CWirc X-chat program. That program
** is issued under the GPL and is
** Copyright (C) Pierre-Philippe Coupard - 18/06/2003
**
** This derived version is
** Copyright (C) 2004-2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
** Doxygen comments added by Dave Larsen, KV0S
*/

// #include <stdio.h>

class iambic_dttsp {
 private:

  static const int NO_TIME_LEFTS_SCHED	= (-2);
  static const int  NO_ELEMENT		= (-1);
  static const int DIT			= (0);
  static const int DAH			= (1);
  static const int MODE_A		= (0);
  static const int MODE_B		= (1);
  static const int NO_PADDLE_SQUEEZE	= (0);
  static const int PADDLES_SQUEEZED	= (1);
  static const int PADDLES_RELEASED	= (2);
  static const int NO_DELAY		= (0);
  static const int CHAR_SPACING_DELAY	= (1);
  static const int WORD_SPACING_DELAY	= (2);

  // KeyerLogic state
  struct {
    struct {
      int dit, dah;
    } prev;
  } flag;
  struct {
    int altrn,		      // insert alternate element
      psqam;		      // paddles squeezed after mid-element
    int curr,		      // -1 = nothing, 0 = dit, 1 = dah
      iamb,		      //  0 = none, 1 = squeezed, 2 = released
      last;		      // -1 = nothing, 0 = dit, 1 = dah
  } element;
  struct {
    double beep, dlay, elem, midl;
  } time_left;
  int dlay_type;	     // 0 = none, 1 = interchar, 2 = interword
  // klogic parameters
  float wpm;
  int iambicmode;
  int need_midelemodeB;
  int want_dit_mem;
  int want_dah_mem;
  int autocharspacing;
  int autowordspacing;
  int weight;
  // computed parameters
  float ditlen;
  
 public:
  iambic_dttsp() {
    flag.prev.dit = 0;
    flag.prev.dah = 0;
    element.last = element.curr = NO_ELEMENT;
    element.iamb = NO_PADDLE_SQUEEZE;
    element.psqam = 0;
    element.altrn = 0;
    time_left.midl = time_left.beep = time_left.elem = 0;
    time_left.dlay = 0;
    dlay_type = NO_DELAY;
  }

  void set_wpm(float _wpm) { ditlen = 1200.0f / (wpm = _wpm); }
  void set_iambicmode_b() { iambicmode = MODE_B; }
  void set_iambicmode_a() { iambicmode = MODE_A; }
  void set_need_midelemodeB(int on) { need_midelemodeB = on; }
  void set_want_dit_mem(int on) { want_dit_mem = on; }
  void set_want_dah_mem(int on) { want_dah_mem = on; }
  void set_autocharspacing(int on) { autocharspacing = on; }
  void set_autowordspacing(int on) { autowordspacing = on; }
  void set_weight(int _weight) { weight = _weight; }

  //
  // given the keyer_t state/option structure pointer,
  // the current states of the dit and dah paddles,
  // and the length of the tick since the last call
  // in some unspecified unit,
  // return true or false depending on whether the keyer output
  // should be on or off
  //
  // ditlen in minutes/dit = minutes/word * word/dit = 1/(wpm * 50) = 
  // ditlen in seconds/dit = 60 * minutes/dit = 60/ (wpm * 50)
  // ditlen in ms/dit = 1000 * seconds/dit = 1200 / wpm
  //

  int clock(int dit, int dah, float ticklen) {
    int set_which_ele_time_left = NO_TIME_LEFTS_SCHED;
    /** Decrement the time_lefts */
    time_left.dlay -= time_left.dlay > 0 ? ticklen : 0;
    if (time_left.dlay <= 0) {
      /* If nothing is scheduled to play,
	 and we just did a character space delay,
	 and we're doing auto word spacing,
	 then pause for a word space,
	 otherwise resume the normal element time_left countdowns */
      if (time_left.elem <= 0 &&
	  dlay_type == CHAR_SPACING_DELAY &&
	  autowordspacing) {
	time_left.dlay = ditlen * 4;
	dlay_type = WORD_SPACING_DELAY;
      } else {
	dlay_type = NO_DELAY;
	time_left.midl -= time_left.midl > 0 ? ticklen : 0;
	time_left.beep -= time_left.beep > 0 ? ticklen : 0;
	time_left.elem -= time_left.elem > 0 ? ticklen : 0;
      }
    }
    
    /** Are both paddles squeezed? */
    if (dit && dah) {
      element.iamb = PADDLES_SQUEEZED;
      /* Are the paddles squeezed past the middle of the element? */
      if (time_left.midl <= 0)
	element.psqam = 1;
    } else if (!dit && !dah && element.iamb == PADDLES_SQUEEZED)
      /* Are both paddles released and we had gotten a squeeze in this element? */
      element.iamb = PADDLES_RELEASED;

    /** Is the current element finished? */
    if (time_left.elem <= 0 && element.curr != NO_ELEMENT) {
      element.last = element.curr;

      /** Should we insert an alternate element? */
      if (((dit && dah) ||
	   (element.altrn &&
	    element.iamb != PADDLES_RELEASED) ||
	   (element.iamb == PADDLES_RELEASED &&
	    iambicmode == MODE_B &&
	    (!need_midelemodeB || element.psqam)))) {
	if (element.last == DAH)
	  set_which_ele_time_left = element.curr = DIT;
	else
	  set_which_ele_time_left = element.curr = DAH;

      } else {
	/* No more element */
	element.curr = NO_ELEMENT;
	/* Do we do automatic character spacing? */
	if (autocharspacing && !dit && !dah) {
	  time_left.dlay = ditlen * 2;
	  dlay_type = CHAR_SPACING_DELAY;
	}
      }

      element.altrn = 0;
      element.iamb = NO_PADDLE_SQUEEZE;
      element.psqam = 0;
    }

    /** Is an element not currently being played? */
    if (element.curr == NO_ELEMENT) {
      if (dah)		/* Dah paddle down? */
	set_which_ele_time_left = element.curr = DAH;
      else if (dit)	/* Dit paddle down? */
	set_which_ele_time_left = element.curr = DIT;
    }

    /** Take the dah memory request into account */
    if (element.curr == DIT &&
	!flag.prev.dah &&
	dah &&
	want_dah_mem)
      element.altrn = 1;

    /** Take the dit memory request into account */
    if (element.curr == DAH &&
	!flag.prev.dit &&
	dit &&
	want_dit_mem)
      element.altrn = 1;

    /** If we had a dit or dah scheduled for after a delay,
	and both paddles are up before the end of the delay,
	and we have not requested dit or dah memory,
	forget it
	NB can't happen in full mode B */

    if (time_left.dlay > 0 && !dit && !dah &&
	((element.curr == DIT && !want_dit_mem) ||
	 (element.curr == DAH && !want_dah_mem)))
      set_which_ele_time_left = element.curr = NO_ELEMENT;

    /** Set element time_lefts, if needed */
    switch (set_which_ele_time_left) {
    case NO_ELEMENT:		/* Cancel any element */
      time_left.beep = 0;
      time_left.midl = 0;
      time_left.elem = 0;
      break;

    case DIT:			/* Schedule a dit */
      time_left.beep = (ditlen * (double) weight) / 50;
      time_left.midl = time_left.beep / 2;
      time_left.elem = ditlen * 2;
      break;

    case DAH:			/* Schedule a dah */
      time_left.beep = (ditlen * (double) weight) / 50 + ditlen * 2;
      time_left.midl = time_left.beep / 2;
      time_left.elem = ditlen * 4;
      break;
    }

    flag.prev.dit = dit;
    flag.prev.dah = dah;

    return (time_left.beep > 0 && time_left.dlay <= 0) ? 1 : 0;
  }
};

extern "C" {
  typedef struct {
    iambic_dttsp k;
  } iambic_dttsp_t;
  
  typedef struct {
    float wpm;
    char mode;
    int want_dit_mem;
    int want_dah_mem;
    int need_midelemodeB;
    int autocharspacing;
    int autowordspacing;
    int weight;
  } iambic_dttsp_options_t;

  static void *iambic_dttsp_init(iambic_dttsp_t *p, iambic_dttsp_options_t *q) {
    return p;
  }

  static void iambic_dttsp_configure(iambic_dttsp_t *p, iambic_dttsp_options_t *q) {
    p->k.set_wpm(q->wpm);
    if (q->mode == 'A')
      p->k.set_iambicmode_a();
    else if (q->mode == 'B')
      p->k.set_iambicmode_b();
    p->k.set_want_dit_mem(q->want_dit_mem);
    p->k.set_want_dah_mem(q->want_dah_mem);
    p->k.set_autocharspacing(q->autocharspacing);
    p->k.set_autowordspacing(q->autowordspacing);
    p->k.set_weight(q->weight);
  }

  static int iambic_dttsp_process(iambic_dttsp_t *p, int dit, int dah, float tick_ms) {
    return p->k.clock(dit, dah, tick_ms);
  }
}
#endif
