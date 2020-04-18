/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA.

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

#ifndef IAMBIC_VK6PH_H
#define IAMBIC_VK6PH_H

/*

    10/12/2016, Rick Koch / N1GP, I adapted Phil's verilog code from
                the openHPSDR Hermes iambic.v implementation to build
                and run on a raspberry PI 3.

    1/7/2017,   N1GP, adapted to work with Jack Audio, much better timing.

    8/3/2018,   Roger Critchlow / AD5DZ/1, I adapted Rick's adaptation to
		run when clocked at specified microseconds per tick, as
		necessary when running inside a jack frame processor callback.
		Rick's code from https://github.com/n1gp/iambic-keyer
--------------------------------------------------------------------------------
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.
This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.
You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the
Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
Boston, MA  02110-1301, USA.
--------------------------------------------------------------------------------


---------------------------------------------------------------------------------
        Copywrite (C) Phil Harman VK6PH May 2014
---------------------------------------------------------------------------------

        The code implements an Iambic CW keyer.  The following features are supported:

                * Variable speed control from 1 to 60 WPM
                * Dot and Dash memory
                * Straight, Bug, Iambic Mode A or B Modes
                * Variable character weighting
                * Automatic Letter spacing
                * Paddle swap

        Dot and Dash memory works by registering an alternative paddle closure whilst a paddle is pressed.
        The alternate paddle closure can occur at any time during a paddle closure and is not limited to being
        half way through the current dot or dash. This feature could be added if required.

        In Straight mode, closing the DASH paddle will result in the output following the input state.  This enables a
        straight morse key or external Iambic keyer to be connected.

        In Bug mode closing the dot paddle will send repeated dots.

        The difference between Iambic Mode A and B lies in what the keyer does when both paddles are released. In Mode A the
        keyer completes the element being sent when both paddles are released. In Mode B the keyer sends an additional
        element opposite to the one being sent when the paddles are released.

        This only effects letters and characters like C, period or AR.

        Automatic Letter Space works as follows: When enabled, if you pause for more than one dot time between a dot or dash
        the keyer will interpret this as a letter-space and will not send the next dot or dash until the letter-space time has been met.
        The normal letter-space is 3 dot periods. The keyer has a paddle event memory so that you can enter dots or dashes during the
        inter-letter space and the keyer will send them as they were entered.

        Speed calculation -  Using standard PARIS timing, dot_period(mS) = 1200/WPM
*/
#include "iambic.h"

class iambic_vk6ph {

private:
  enum {
    CHECK = 0,
    PREDOT,
    PREDASH,
    SENDDOT,
    SENDDASH,
    DOTDELAY,
    DASHDELAY,
    DOTHELD,
    DASHHELD,
    LETTERSPACE,
    EXITLOOP
  };
  enum {
    KEYER_STRAIGHT = 0,
    KEYER_MODE_A,
    KEYER_MODE_B
  };
  int dot_memory = 0;
  int dash_memory = 0;
  int key_state = CHECK;
  int kdelay = 0;
  int dot_delay = 0;
  int dash_delay = 0;
  int kcwl = 0;
  int kcwr = 0;
  int *kdot;
  int *kdash;
  int cw_keyer_speed = 20;
  int cw_keyer_weight = 55;
  int cw_keys_reversed = 0;
  int cw_keyer_mode = KEYER_MODE_B;
  int cw_keyer_spacing = 0;

  float cw_micros_per_tick = 1000000.0/48000.0;
  
  int keyer_out = IAMBIC_OFF;

  void keyer_update() {
    dot_delay = (int)(((1200000.0 / cw_keyer_speed) / cw_micros_per_tick) + 0.5);
    // will be 3 * dot length at standard weight
    dash_delay = (dot_delay * 3 * cw_keyer_weight) / 50;

    if (cw_keys_reversed) {
      kdot = &kcwr;
      kdash = &kcwl;
    } else {
      kdot = &kcwl;
      kdash = &kcwr;
    }
  }
  void clear_memory() {
    dot_memory  = 0;
    dash_memory = 0;
  }


public:
  iambic_vk6ph() {
    cw_keys_reversed = 0;	/* (0=not, 1=reversed) */
    cw_keyer_spacing = 0;	/* (0=off, 1=on) */
    cw_keyer_mode = 2;		/* (0=straight or bug, 1=iambic_a, 2=iambic_b) */
    cw_keyer_speed = 20;	/* speed wpm */
    cw_keyer_weight = 55;	/* weight 33-66 */
    cw_micros_per_tick = 1000000.0/48000.0;
    keyer_update();
  }
  
  void set_cw_keys_reversed(int swap) { cw_keys_reversed = swap; keyer_update(); }
  void set_cw_keyer_spacing(int onoff) { cw_keyer_spacing = onoff != 0; }
  void set_cw_keyer_mode(int mode) { 
    cw_keyer_mode = 
      mode == 'S' ? KEYER_STRAIGHT :
      mode == 'A' ? KEYER_MODE_A :
      mode == 'B' ? KEYER_MODE_B :
      mode; 
  }
  void set_cw_keyer_speed(int wpm) { cw_keyer_speed = wpm; keyer_update(); }
  void set_cw_keyer_weight(int pct) { cw_keyer_weight = pct; keyer_update();  }
  void set_cw_micros_per_tick(float tick) { cw_micros_per_tick = tick; keyer_update(); }

  int clock(int raw_dit_on, int raw_dah_on, int ticks) {
    kcwl = raw_dit_on;
    kcwr = raw_dah_on;
    
    switch(key_state) {
    case CHECK:		// check for key press
      if (cw_keyer_mode == KEYER_STRAIGHT) { // Straight/External key or bug
	if (*kdash) {	// send manual dashes
	  keyer_out = IAMBIC_DAH;
	  key_state = CHECK;
	} else if (*kdot)	// and automatic dots
	  key_state = PREDOT;
	else {
	  keyer_out = IAMBIC_OFF;
	  key_state = CHECK;
	}
      } else {
	if (*kdot)
	  key_state = PREDOT;
	else if (*kdash)
	  key_state = PREDASH;
	else {
	  keyer_out = IAMBIC_OFF;
	  key_state = CHECK;
	}
      }
      break;
    case PREDOT:	   // need to clear any pending dots or dashes
      clear_memory();
      key_state = SENDDOT;
      break;
    case PREDASH:
      clear_memory();
      key_state = SENDDASH;
      break;

      // dot paddle  pressed so set keyer_out high for time dependant on speed
      // also check if dash paddle is pressed during this time
    case SENDDOT:
      keyer_out = IAMBIC_DIT;
      if (kdelay >= dot_delay) {
	kdelay = 0;
	keyer_out = IAMBIC_OFF;
	key_state = DOTDELAY; // add inter-character spacing of one dot length
      } else
	kdelay += ticks;

      // if Mode A and both paddels are relesed then clear dash memory
      if (cw_keyer_mode == KEYER_MODE_A)
	if (!*kdot & !*kdash)
	  dash_memory = 0;
	else if (*kdash)	// set dash memory
	  dash_memory = 1;
      break;

      // dash paddle pressed so set keyer_out high for time dependant on 3 x dot delay and weight
      // also check if dot paddle is pressed during this time
    case SENDDASH:
      keyer_out = IAMBIC_DAH;
      if (kdelay >= dash_delay) {
	kdelay = 0;
	keyer_out = IAMBIC_OFF;
	key_state = DASHDELAY; // add inter-character spacing of one dot length
      } else 
	kdelay += ticks;

      // if Mode A and both padles are relesed then clear dot memory
      if (cw_keyer_mode == KEYER_MODE_A)
	if (!*kdot & !*kdash)
	  dot_memory = 0;
	else if (*kdot)	// set dot memory
	  dot_memory = 1;
      break;

      // add dot delay at end of the dot and check for dash memory, then check if paddle still held
    case DOTDELAY:
      if (kdelay >= dot_delay) {
	kdelay = 0;
	if(!*kdot && cw_keyer_mode == KEYER_STRAIGHT)   // just return if in bug mode
	  key_state = CHECK;
	else if (dash_memory) // dash has been set during the dot so service
	  key_state = PREDASH;
	else 
	  key_state = DOTHELD; // dot is still active so service
      } else
	kdelay += ticks;

      if (*kdash)		// set dash memory
	dash_memory = 1;
      break;

      // add dot delay at end of the dash and check for dot memory, then check if paddle still held
    case DASHDELAY:
      if (kdelay >= dot_delay) {
	kdelay = 0;

	if (dot_memory) // dot has been set during the dash so service
	  key_state = PREDOT;
	else 
	  key_state = DASHHELD; // dash is still active so service
      } else
	kdelay += ticks;

      if (*kdot)		// set dot memory
	dot_memory = 1;
      break;

      // check if dot paddle is still held, if so repeat the dot. Else check if Letter space is required
    case DOTHELD:
      if (*kdot)	// dot has been set during the dash so service
	key_state = PREDOT;
      else if (*kdash)	// has dash paddle been pressed
	key_state = PREDASH;
      else if (cw_keyer_spacing) { // Letter space enabled so clear any pending dots or dashes
	clear_memory();
	key_state = LETTERSPACE;
      } else
	key_state = CHECK;
      break;

      // check if dash paddle is still held, if so repeat the dash. Else check if Letter space is required
    case DASHHELD:
      if (*kdash)	// dash has been set during the dot so service
	key_state = PREDASH;
      else if (*kdot)	// has dot paddle been pressed
	key_state = PREDOT;
      else if (cw_keyer_spacing) { // Letter space enabled so clear any pending dots or dashes
	clear_memory();
	key_state = LETTERSPACE;
      } else
	key_state = CHECK;
      break;

      // Add letter space (3 x dot delay) to end of character and check if a paddle is pressed during this time.
      // Actually add 2 x dot_delay since we already have a dot delay at the end of the character.
    case LETTERSPACE:
      if (kdelay >= 2 * dot_delay) {
	kdelay = 0;
	if (dot_memory) // check if a dot or dash paddle was pressed during the delay.
	  key_state = PREDOT;
	else if (dash_memory)
	  key_state = PREDASH;
	else
	  key_state = CHECK; // no memories set so restart
      } else
	kdelay += ticks;

      // save any key presses during the letter space delay
      if (*kdot) dot_memory = 1;
      if (*kdash) dash_memory = 1;
      break;

    default:
      key_state = CHECK;

    }
    
    return keyer_out;
  }
};

extern "C" {
  typedef struct {
    iambic_vk6ph k;
  } iambic_vk6ph_t;
  typedef struct {
  } iambic_vk6ph_options_t;
}
#endif // IAMBIC_VK6PH_H
