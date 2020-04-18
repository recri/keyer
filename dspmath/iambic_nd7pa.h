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

#ifndef IAMBIC_ND7PA_H
/*
** This has been stripped down to the minimal iambic state machine
** from the AVR sources that accompany the article in QEX March/April
** 2012, and the length of the dah and inter-element-space has been
** made into configurable multiples of the dit clock.
*/
/*
* newkeyer.c  an electronic keyer with programmable outputs 
* Copyright (C) 2012 Roger L. Traylor   
* 
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
* 
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* 
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// newkeyer.c    
// R. Traylor
// 3.19.2012
// iambic keyer      
#include "iambic.h"

class iambic_nd7pa {
private:
  // keyer states
  static const int IDLE =     0;  // waiting for a paddle closure 
  static const int DIT =      1;  // making a dit 
  static const int DAH =      2;  // making a dah  
  static const int DIT_DLY =  3;  // intersymbol delay, one dot time
  static const int DAH_DLY =  4;  // intersymbol delay, one dot time

  // state variables
  int keyer_state;	// the keyer state 
  bool dit_pending;	// memory for dits  
  bool dah_pending;	// memory for dahs  
  int timer;		// ticks counting down

  // ticks per feature
  int _ticksPerDit;
  int _ticksPerDah;
  int _ticksPerIes;

  // parameters
  float _tick;			// microseconds per tick
  bool _swapped;		// true if paddles are swapped
  float _wpm;			// words per minute
  float _ditLen;		// dits per dit
  float _dahLen;		// dits per dah
  float _iesLen;		// dits per space between dits and dahs

  // update the clock computations
  void update() {
    // microsecond timing
    float microsPerDit = 60000000.0 / (_wpm * 50);

    // tick timing
    _ticksPerDit = (microsPerDit * _ditLen) / _tick + 0.5;
    _ticksPerDah = (microsPerDit * _dahLen) / _tick + 0.5;
    _ticksPerIes = (microsPerDit * _iesLen) / _tick + 0.5;
  }

public:
  iambic_nd7pa() {
    keyer_state = IDLE;
    dit_pending = false;
    dah_pending = false;
    setTick(1);
    setSwapped(false);
    setWpm(15);
    setDah(3);
    setIes(1);
    update();
  }

  int clock(int raw_dit_on, int raw_dah_on, int ticks) {

    bool dit_on = (_swapped ? raw_dah_on : raw_dit_on) != 0;
    bool dah_on = (_swapped ? raw_dit_on : raw_dah_on) != 0;
    char key_out = IAMBIC_OFF;

    // update timer
    timer -= ticks;
    bool timer_expired = timer <= 0;

    // keyer state machine   
    if (keyer_state == IDLE) {
      key_out = IAMBIC_OFF;
      if (dit_on) {
	timer = _ticksPerDit; keyer_state = DIT;
      } else if (dah_on) {
	timer = _ticksPerDah; keyer_state = DAH;
      }       
    } else if (keyer_state == DIT) {
      key_out = IAMBIC_DIT; 
      if ( timer_expired ) { timer = _ticksPerIes; keyer_state = DIT_DLY; }  
    } else if (keyer_state == DAH) {
      key_out = IAMBIC_DAH; 
      if ( timer_expired ) { timer = _ticksPerIes; keyer_state = DAH_DLY; }  
    } else if (keyer_state == DIT_DLY) {
      key_out = IAMBIC_OFF;  
      if ( timer_expired ) {
	if ( dah_pending ) { timer = _ticksPerDah; keyer_state = DAH;
	} else { keyer_state = IDLE; }
      }
    } else if (keyer_state == DAH_DLY) {
      key_out = IAMBIC_OFF; 
      if ( timer_expired ) {
        if ( dit_pending ) {
	  timer = _ticksPerDit; keyer_state = DIT;
	} else {
	  keyer_state = IDLE;
	}
      }
    }

    //*****************  dit pending state machine   *********************
    dit_pending = dit_pending ?
      keyer_state != DIT :
      (dit_on && ((keyer_state == DAH && timer < _ticksPerDah/3) ||
		  (keyer_state == DAH_DLY && timer > _ticksPerIes/2)));
         
    //******************  dah pending state machine   *********************
    dah_pending = dah_pending ?
      keyer_state != DAH :
      (dah_on && ((keyer_state == DIT && timer < _ticksPerDit/2) ||
		  (keyer_state == DIT_DLY && timer > _ticksPerIes/2)));

    return key_out;
  }

  // set the microseconds in a tick
  void setTick(float tick) { _tick = tick; update(); }
  float getTick() { return _tick; }
  // set the words per minute generated
  void setWpm(float wpm) { _wpm = wpm; update(); }
  float getWpm() { return _wpm; }
  // swap the dit and dah paddles
  void setSwapped(bool swapped) { _swapped = swapped; }
  bool getSwapped() { return _swapped; } 
  // set the dit length in dits
  void setDit(float ditLen) { _ditLen = ditLen; update(); }
  float getDit() { return _ditLen; }
  // set the dah length in dits
  void setDah(float dahLen) { _dahLen = dahLen; update(); }
  float getDah() { return _dahLen; }
  // set the inter-element length in dits
  void setIes(float iesLen) { _iesLen = iesLen; update(); }
  float getIes() { return _iesLen; }
};

extern "C" {
  typedef struct {
    iambic_nd7pa k;
  } iambic_nd7pa_t;
  typedef struct {
  } iambic_nd7pa_options_t;
}
#endif
