
/*
 *      This program is free software; you can redistribute it and/or modify
 *      it under the terms of the GNU General Public License as published by
 *      the Free Software Foundation; either version 2 of the License, or
 *      (at your option) any later version.
 *      
 *      This program is distributed in the hope that it will be useful,
 *      but WITHOUT ANY WARRANTY; without even the implied warranty of
 *      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *      GNU General Public License for more details.
 *      
 *      You should have received a copy of the GNU General Public License
 *      along with this program; if not, write to the Free Software
 *      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *      MA 02110-1301, USA.
 */



/*  * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 Main code by Thomas O Fredericks
 Rebounce and duration functions contributed by Eric Lowry
 Write function contributed by Jim Schimpf
 risingEdge and fallingEdge contributed by Tom Harkaway
 Rewritten to be a class in a class and to allow microsecond
 timing by Roger E Critchlow Jr
* * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#ifndef Bounce_h
#define Bounce_h

#include <inttypes.h>

class Bounce {

 public:
  // Initialize
  Bounce(uint8_t pin,unsigned long interval_micros) {
    interval(interval_micros);
    previous_micros = micros();
    state = digitalRead(pin);
    this->pin = pin;
  }

  // Sets the debounce interval
  void interval(unsigned long interval_micros) {
    this->interval_micros = interval_micros;
    this->rebounce_micros = 0;
  }

  // Updates the pin
  // Returns 1 if the state changed
  // Returns 0 if the state did not change
  int update() {
    if ( debounce() ) {
      rebounce(0);
      return stateChanged = 1;
    }

    // We need to rebounce, so simulate a state change
    if ( rebounce_micros && (micros() - previous_micros >= rebounce_micros) ) {
      previous_micros = micros();
      rebounce(0);
      return stateChanged = 1;
    }
    return stateChanged = 0;
  }

  // Forces the pin to signal a change (through update()) in X microseconds 
  // even if the state does not actually change
  // Example: press and hold a button and have it repeat every X microseconds
  void rebounce(unsigned long interval) { rebounce_micros = interval; }

  // Returns the updated pin state
  int read() { return (int)state; }

  // Sets the stored pin state
  void write(int new_state) { state = new_state; digitalWrite(pin,state); }

  // Returns the number of microseconds the pin has been in the current state
  unsigned long duration() { return micros() - previous_micros; }

  // The risingEdge method is true for one scan after the de-bounced input goes from off-to-on.
  bool risingEdge() { return stateChanged && state; }

  // The fallingEdge  method it true for one scan after the de-bounced input goes from on-to-off. 
  bool  fallingEdge() { return stateChanged && !state; }
  
 protected:

  // Protected: debounces the pin
  int debounce() {
    uint8_t newState = digitalRead(pin);
    if (state != newState ) {
      if (micros() - previous_micros >= interval_micros) {
	previous_micros = micros();
	state = newState;
	return 1;
      }
    }
    return 0;
  }

  unsigned long  previous_micros, interval_micros, rebounce_micros;
  uint8_t state;
  uint8_t pin;
  uint8_t stateChanged;
};

#endif


