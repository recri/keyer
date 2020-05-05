/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2011, 2012, 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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
#ifndef IAMBIC_AD5DZ_H
#define IAMBIC_AD5DZ_H

/*
** A morse code keyer reduced to a simple logic class.
**
** // usage
**
** // to make a keyer
** iambic_ad5dz k();
**
** // to specify the current paddle state,
** // advance the keyer clock by ticks
** // and receiver the current keyout state.
** keyout = k.clock(dit, dah, ticks);	
**
** // the units of ticks is specified with
** k.setTick(microseconds)
**
** // parameter setting
** k.set*(param)
**
** // parameter query
** k.get*(param)
*/

/*
** May need to parameterize the ticks type
** in case the int is too small on an microprocessor
*/

// #include <stdio.h>
#include "iambic.h"

class iambic_ad5dz {
private:
#define KEYIN(dit,dah) (((dit)<<1)|(dah))
  typedef unsigned char byte;
  //static int KEYIN(int dit, int dah) { return ((dit<<1)|dah); }
  static const int KEYIN_OFF = KEYIN(0,0);
  static const int KEYIN_DIT = KEYIN(1,0);
  static const int KEYIN_DAH = KEYIN(0,1);
  static const int KEYIN_DIDAH = KEYIN(1,1);
  static bool KEYIN_IS_OFF(int keyIn) { return keyIn == KEYIN_OFF; }
  static bool KEYIN_IS_DIT(int keyIn) { return (keyIn&KEYIN_DIT)!=0; }
  static bool KEYIN_IS_DAH(int keyIn) { return (keyIn&KEYIN_DAH)!=0; }
  static bool KEYIN_IS_DIDAH(int keyIn) { return keyIn == KEYIN_DIDAH; }
  
public:
  iambic_ad5dz() {
    _update = true;

    _keyIn = KEYIN_OFF;
    _lastKeyIn = KEYIN_OFF;
    _startKeyIn = KEYIN_OFF;
    _halfClockKeyIn = KEYIN_OFF;

    setTiming(1, 15, 50, 1, 3, 1, 3, 7);
    setModes('A', false, false, false);
    update();
  }

  // clock ticks
  int clock(int raw_dit_on, int raw_dah_on, int ticks) {
    // update timings if necessary
    if (_update) update();

    // fetch input state
    byte keyIn = fix_swapped(raw_dit_on, raw_dah_on);
      //  ? KEYIN(raw_dah_on&1, raw_dit_on&1) : KEYIN(raw_dit_on&1, raw_dah_on&1);
    if (_keyIn != keyIn) {
      _lastKeyIn = _keyIn;
      _memKeyIn |= keyIn & ~_startKeyIn;
      _keyIn = keyIn;
      // if (_verbose) fprintf(stderr, "iambic._keyIn = %x\n", _keyIn);
    }

    // start a symbol if either paddle is pressed
    if (_keyerState == KEYER_OFF) {
      _startSymbol();
      return _keyOut;
    }

    // if the half clock is running,
    // reduce by the time elapsed;
    // if the half clock duration elapsed;
    // remember the current squeeze
    if (_halfClockDuration > 0 && (_halfClockDuration -= ticks) == 0) _halfClockKeyIn = _keyIn;

    // reduce the duration by the time elapsed
    // if the duration has not elapsed, return
    if ((_keyerDuration -= ticks) > 0) return _keyOut;

    // determine the next element by the current paddle state
    switch (_keyerState) {
    // finish the dit with an interelement space
    case KEYER_DIT: _startSpace(KEYER_DIT_SPACE); break;
    // finish the dah with an interelement space
    case KEYER_DAH: _startSpace(KEYER_DAH_SPACE); break;
    // start the next element or finish the symbol
    case KEYER_DIT_SPACE: _startDah() || _startDit() || _symbolSpace() || _finish(); break;
    // start the next element or finish the symbol	    
    case KEYER_DAH_SPACE: _startDit() || _startDah() || _symbolSpace() || _finish(); break;
    // start a new symbol or finish the word
    case KEYER_SYMBOL_SPACE: _startSymbol() || _wordSpace() || _finish(); break;
    // start a new symbol or go to off
    case KEYER_WORD_SPACE: _startSymbol() || _finish(); break;
    }
    return _keyOut;
  }

  // set the timing
  void setTiming(float tick, float wpm, float word, float ditLen, float dahLen, float iesLen, float ilsLen, float iwsLen) {
    _tick = tick;	       // set the microseconds in a tick
    _wpm = wpm;		       // set the words per minute generated
    _word = word;	       // set the word length in dits
    _ditLen = ditLen;	       // set the dit length in dits
    _dahLen = dahLen;	       // set the dah length in dits 
    _iesLen = iesLen;	       // set the inter-element length in dits
    _ilsLen = ilsLen;	       // set the inter-letter length in dits
    _iwsLen = iwsLen;	       // set the inter-word length in dits
    _update = true;	       // recompute timing
  }
  // set the modes
  void setModes(char mode, bool swapped, bool autoIls, bool autoIws) {
    _mode = mode;		// set the paddle key mode
    _swapped = swapped;		// swap the dit and dah paddles
    _autoIls = autoIls;		// set the auto inter-letter spacing
    _autoIws = autoIws;		// set the auto inter-word spacing
    fix_swapped = _swapped ? &is_swapped : &is_not_swapped;
  }
  // set the level of verbosity
  void setVerbose(int verbose) { _verbose = verbose; _update = true; }
  
 private:

  // build key state for swapped and unswapped states
  static byte is_swapped(int raw_dit_on, int raw_dah_on) { return KEYIN(raw_dah_on&1, raw_dit_on&1); }
  static byte is_not_swapped(int raw_dit_on, int raw_dah_on) { return KEYIN(raw_dit_on&1, raw_dah_on&1); }
  byte (*fix_swapped)(int raw_dit_on, int raw_dit_off) = &is_not_swapped;

  // update the clock computations
  void update() {
    if (_update) {
      _update = false;
      // microsecond timing
      float microsPerDit = 60000000.0 / (_wpm * _word);
      // tick timing
      _ticksPerDit = (microsPerDit * _ditLen) / _tick + 0.5;
      _ticksPerDah = (microsPerDit * _dahLen) / _tick + 0.5;
      _ticksPerIes = (microsPerDit * _iesLen) / _tick + 0.5;
      _ticksPerIls = (microsPerDit * _ilsLen) / _tick + 0.5;
      _ticksPerIws = (microsPerDit * _iwsLen) / _tick + 0.5;
    }
  }

  typedef enum {
    KEY_OFF, KEY_DIT, KEY_DAH, KEY_DIDAH
  } keyState;
  typedef enum {
    KEYER_OFF, KEYER_DIT, KEYER_DIT_SPACE, KEYER_DAH, KEYER_DAH_SPACE, KEYER_SYMBOL_SPACE, KEYER_WORD_SPACE,
  } keyerState;

  float _tick;			// microseconds per tick
  byte _verbose;		// chatter
  bool _swapped;		// true if paddles are swapped
  char _mode;			// mode B or mode A or ...
  float _word;			// dits per word, 50 or 60
  float _wpm;			// words per minute
  float _ditLen;		// dits per dit
  float _dahLen;		// dits per dah
  float _iesLen;		// dits per space between dits and dahs
  float _ilsLen;		// dits per space between letters
  float _iwsLen;		// dits per space between words
  bool _autoIls;		// automatically time space between letters
  bool _autoIws;		// automatically time space between words
  
  bool _update;			// update computed values

  byte _keyOut;			// output key state
  byte _keyIn;			// input key didah state, swapped
  byte _lastKeyIn;		// previous input key didah state
  byte _startKeyIn;		// key state at beginning of current element
  byte _memKeyIn;		// memory of states seen since element began
  byte _halfClockKeyIn;		// memory of key state halfway through element
  keyerState _keyerState;	// current keyer state
  int _halfClockDuration;	// ticks to next midelement transition
  int _keyerDuration;		// ticks to next keyer state transition

  // ticks per feature
  int _ticksPerDit;
  int _ticksPerDah;
  int _ticksPerIes;
  int _ticksPerIls;
  int _ticksPerIws;

  // transition to the specified state
  // with the specified duration
  // and set the key out state
  bool _transitionTo(keyerState newState, int newDuration, bool keyOut) {
    _keyOut = keyOut ? (newState == KEYER_DIT ? IAMBIC_DIT : IAMBIC_DAH) : IAMBIC_OFF;
    if (keyOut) {
      _memKeyIn = 0;
      _startKeyIn = _keyIn;
      _halfClockDuration = newDuration / 2;
    }
    return _transitionTo(newState, newDuration);
  }
  
  // transition to the specified state
  // with the specified duration
  bool _transitionTo(keyerState newState, int newDuration) {
    _keyerState = newState;
    _keyerDuration += newDuration;
    return true;
  }

  // at the beginning of the next symbol
  // we may be currently at dit+dah, but
  // we want to start with which ever
  // paddle was pressed first
  bool _startSymbol() {
    if (_keyIn != KEYIN_DIDAH || _lastKeyIn != KEYIN_DAH)
      return _startDit() || _startDah();
    else
      return _startDah() || _startDit();
  }
  // start a dit if it should be
  bool _startDit() {
    return ((KEYIN_IS_OFF(_keyIn) && _mode == 'B' && KEYIN_IS_DIDAH(_halfClockKeyIn)) ||
	    KEYIN_IS_DIT(_keyIn|_memKeyIn)) &&
      _transitionTo(KEYER_DIT, _ticksPerDit, true);
  }
  // start a dah if it should be
  bool _startDah() {
    return ((KEYIN_IS_OFF(_keyIn) && _mode == 'B' && KEYIN_IS_DIDAH(_halfClockKeyIn)) ||
	    KEYIN_IS_DAH(_keyIn|_memKeyIn)) &&
      _transitionTo(KEYER_DAH, _ticksPerDah, true);
  }
  // start an interelement space
  bool _startSpace(keyerState newState) { return _transitionTo(newState, _ticksPerIes, false); }
  // continue an interelement space to an intersymbol space
  // or an intersymbol space to an interword space
  bool _continueSpace(keyerState newState, int newDuration) { return _transitionTo(newState, newDuration); }
  // continue an interelement space into an intersymbol space
  bool _symbolSpace() { return _autoIls && _continueSpace(KEYER_SYMBOL_SPACE, _ticksPerIls-_ticksPerIes); }
  // continue an intersymbol space into an interword space
  bool _wordSpace() { return _autoIws && _continueSpace(KEYER_WORD_SPACE, _ticksPerIws-_ticksPerIls); }
  // return to keyer idle state
  bool _finish() { return _transitionTo(KEYER_OFF, 0); }
};

extern "C" {
  typedef struct {
    iambic_ad5dz k;
  } iambic_ad5dz_t;
  typedef struct {
  } iambic_ad5dz_options_t;
}

#endif
