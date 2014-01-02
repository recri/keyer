/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2013 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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
  This keyer is a direct derivation from http://openqrp.org/?p=343
  We've just inverted the logic so it runs in a class that is fed
  its input bit changes.
*/

//
// Arduino Iambic Keyer
// October 23rd, 2009
//
// I present a basic iambic mode keyer that has adjustable speed
// and can be configured to operate in iambic mode a or b.
// At this point all it does is flash an LED in Morse, but it’s
// a good foundation to build upon.  There really isn’t anything novel
// about it, it’s the same basic algorithm used by many different keyers.
// Over the weeks I will add autospace, Ultimatic, and straight keying modes.
// I’ll also include the ability to swap paddles. But this will hold us
// for quite a while.  You can cut and paste this into an empty Arduino
// sketch, it’s completely self contained. It’ll run on any Arduino board,
// just wire up a paddle and it will flash the LED. Add a pushbutton switch
// and you can select between iambic mode a and b. It would be very simple
// to add a keying output in place of the LED drive, probably a good idea
// to include a 2N2222 or 2N7000 buffer stage.
//
// #include <avr/interrupt.h>
// #include <avr/io.h>
// #include <stdio.h>

/////////////////////////////////////////////////////////////////////////////////////////
//
//  Iambic Morse Code Keyer Sketch
//  Copyright (c) 2009 Steven T. Elliott
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details:
//
//  Free Software Foundation, Inc., 59 Temple Place, Suite 330,
//  Boston, MA  02111-1307  USA
//
/////////////////////////////////////////////////////////////////////////////////////////

#ifndef IAMBIC_K1EL_H
#define IAMBIC_K1EL_H

/*
** // usage
**
** // to make a keyer
** iambic_k1el k();
**
** // to specify the current paddle state,
** // advance the keyer clock by ticks
** // and receiver the current keyout state.
** keyout = k.clock(dit, dah, ticks);	
**
** // parameter setting
** k.set*(param)
**
** // parameter query
** k.get*(param)
*/

class iambic_k1el {
 private:
  //  keyerControl bit definitions
  static const int DIT_L = 0x01;     // Dit latch
  static const int DAH_L = 0x02;     // Dah latch
  static const int DIT_PROC = 0x04;  // Dit is being processed

  float _tick;			// microseconds per tick
  bool _swapped;		// true if paddles are swapped
  char _mode;			// mode B or mode A or ...
  float _word;			// dits per word, 50 or 60
  float _wpm;			// words per minute
  float _dahLen;		// dits per dah
  float _iesLen;		// dits per space between dits and dahs

  bool _update;			// update computed values
  int _keyerDuration;		// ticks to next keyer state transition
  unsigned char _keyOut;	// output key state

  unsigned long       _ditTime;                    // No. milliseconds per dit
  unsigned char       _keyerControl;
  unsigned char	      _keyerState;

  //  State Machine Defines

  enum KSTYPE {
    IDLE,
    CHK_DIT,
    CHK_DAH,
    KEYED_PREP,
    KEYED,
    INTER_ELEMENT,
  };

  void update() {
    if (_update) {
      _update = false;
      // microsecond timing
      float microsPerDit = 60000000.0 / (_wpm * _word);
      // tick timing
      _ticksPerDit = microsPerDit / _tick + 0.5;
      _ticksPerDah = (microsPerDit * _dahLen) / _tick + 0.5;
      _ticksPerIes = (microsPerDit * _iesLen) / _tick + 0.5;
    }
  }

  ///////////////////////////////////////////////////////////////////////////////
  //
  //    Latch dit and/or dah press
  //
  //    Called by keyer routine
  //
  ///////////////////////////////////////////////////////////////////////////////

  void update_PaddleLatch(int raw_dit_on, int raw_dah_on) {
    if (_swap) {
      if (raw_dit_on) keyerControl |= DAH_L;
      if (raw_dah_on) keyerControl |= DIT_L;
    } else {
      if (raw_dit_on) keyerControl |= DIT_L;
      if (raw_dah_on) keyerControl |= DAH_L;
    }
  }

 public:
  iambic_k1el() {

    _update = true;
    _keyerState = IDLE;
    _keyerControl = 0;

    setTick(1);
    setSwapped(false);
    setMode('A');
    setWord(50);
    setWpm(15);
    setDah(3);
    setIes(1);

    update();
  }

  // microseconds in a tick
  void setTick(float tick) { _tick = tick; _update = true; }
  float getTick() { return _tick; }

  //  words per minute generated
  void setWpm(float wpm) { _wpm = wpm; _update = true; }
  float getWpm() { return _wpm; }

  // word length in dits
  void setWord(float word) { _word = word; _update = true; }
  float getWord() { return _word; }

  // iambic mode: A or B
  void setMode(char mode) { _mode = mode; }
  char getMode() { return _mode; }

  // swap the dit and dah paddles
  void setSwapped(bool swapped) { _swapped = swapped; }
  bool getSwapped() { return _swapped; } 

  // dah length in dits
  void setDah(float dahLen) { _dahLen = dahLen; _update = true; }
  float getDah() { return _dahLen; }

  // inter-element length in dits
  void setIes(float iesLen) { _iesLen = iesLen; _update = true; }
  float getIes() { return _iesLen; }

  // advance the clock by ticks, notice paddle state changes, return key on or off
  int clock(int raw_dit_on, int raw_dah_on, int ticks) {

    // update timings if necessary
    if (_update) update();

    // Basic Iambic Keyer
    // keyerControl contains processing flags and keyer mode bits
    // Supports Iambic A and B
    // State machine based

    while (1 == 1) {	// loop to here with continue to advance state

      switch (_keyerState) {

      case IDLE:	// Wait for direct or latched paddle press
	if (raw_dit_on || raw_dah_on || (keyerControl & (DIT_L|DAH_L))) {
	  update_PaddleLatch(raw_dit_on, raw_dah_on);
	  _keyerState = CHK_DIT;
	  continue;
	}
	return _keyOut;

      case CHK_DIT:	// See if the dit paddle was pressed
	if (keyerControl & DIT_L) {
	  _keyerControl |= DIT_PROC;
	  _keyerDuration = _ticksPerDit;
	  _keyerState = KEYED_PREP;
	  continue;
	}
	_keyerState = CHK_DAH;
	continue;

      case CHK_DAH:	// See if dah paddle was pressed
	if (keyerControl & DAH_L) {
	  _keyerDuration = _ticksPerDah;
	  _keyerState = KEYED_PREP;
	  continue;
	}
	_keyerState = IDLE;
	return _keyOut;

      case KEYED_PREP:	// Assert key down, start timing, state shared for dit or dah
	_keyOut = 1;
	_keyerControl &= ~(DIT_L + DAH_L);   // clear both paddle latch bits
	_keyerState = KEYED;                 // next state
	return _keyOut;

      case KEYED:	// Wait for timer to expire
	if ((_keyerDuration -= ticks) > 0) {
	  if (mode == 'B') update_PaddleLatch(raw_dit_on, raw_dah_on);	// early paddle latch in Iambic B mode
	  return _keyOut;
	}
	_keyOut = 0;		       // key is off
	_keyerDuration = _ticksPerIes; // inter-element time
	_keyerState = INTER_ELEMENT;   // next state
	return _keyOut;

      case INTER_ELEMENT:// Insert time between dits/dahs
	update_PaddleLatch(raw_dit_on, raw_dah_on); // latch paddle state
	if ((_keyerDuration -= ticks) > 0) {
	  return _keyOut;
	}
	if (_keyerControl & DIT_PROC) {	// was it a dit or dah ?
	  _keyerControl &= ~(DIT_L + DIT_PROC); // clear two bits
	  _keyerState = CHK_DAH;	// dit done, check for dah
	  continue;
	}
	_keyerControl &= ~(DAH_L);	// clear dah latch
	_keyerState = IDLE;		// go idle
	continue;

      } // end switch
      
    } // end while
  }
}

extern "C" {
  typedef struct {
    iambic_k1el k;
  } iambic_t;
  typedef struct {
  } iambic_options_t;
}

#endif
