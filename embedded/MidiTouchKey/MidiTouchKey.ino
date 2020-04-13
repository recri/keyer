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
/* Iambic paddles to USB MIDI

   You must select MIDI from the "Tools > USB Type" menu,
   or Serial + MIDI if you want use Serial.println for debugging

   This is a very trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.

   To use it, you need:

   1) to get a Teensy 4.X, 3.X or LC from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html

   Reprogramming your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device may be problematic.  It's less problematic
   than it was years ago.

  This version is for a sandwich touch key with two TRRS jacks mounted
  between the touch paddles.  Either use it as a standalone touch key
  or plug in your paddles.

  The third switch on TRRS gets reported as note 1+dah, for whatever purposes
  you can find for it.

  The Teensy 4 is not supported yet, I need to include a capacitive touch library
  for it.
*/

#include "WProgram.h"

// optional debug tracing
//#define DEBUGGING 1
#ifdef DEBUGGING
void debuggingsetup() {
  Serial.begin(9600);
}
#define debugprint(x) Serial.print(x)
#define debugprintln(x) Serial.println(x)
#else
#define debugprint(x) /* Serial.print(x) */
#define debugprintln(x) /* Serial.println(x) */
#endif

/*
 * Revised 2020-04-13 to use new paddle/note mapping
 * Also blew off the Keyboard mapping
 */
#define MIDI_KEYER_KEY 3 /* the straight key, mono tip */
#define MIDI_KEYER_DIT 0  /* the left paddle, stereo/trrs tip */
#define MIDI_KEYER_DAH 1  /* the right paddle, stereo ring / trrs ring1 */
#define MIDI_KEYER_AUX 2    /* the other button, trrs ring2 */

enum key_type { switch_key, touch_key, ground, output_active_high, output_active_low };
enum connect_type { tip, ring1, ring2, shield, other };
struct key {
  enum key_type type;
  enum connect_type ctype;
  int channel;      // MIDI channel
  int note;         // MIDI note
  int pin;          // Arduino pin
  int enabled;      // is this key enabled
  uint32_t transition_timeout;  // the millisecond timeout after a transition
  int touch_threshold;          // the threshold between on and off
  uint32_t transition_time;     // start of current blackout period or zero
  int key;                      // current key value, active low
  int touch_level;		// current touch sense value
  int raw_touch_level;		// unnormalized touch sense value
  int raw_touch_level_max;	// maximum touch sense value
  int raw_touch_level_min;	// minimum touch sense value
  int raw_touch_level_sum;
  int raw_touch_level_n;
} key[] = {
  { ground,    shield, 0,              0, 8, 1, 0 },
  { switch_key,   tip, 1, MIDI_KEYER_DIT, 7, 1, 1 },
  { switch_key, ring1, 1, MIDI_KEYER_DAH, 6, 1, 1 },
  { switch_key, ring2, 1, MIDI_KEYER_AUX, 5, 1, 1 },
  { ground,    shield, 0,              0,13, 1, 0 },	// should be pin 17, wiring FU
  { switch_key,   tip, 1, MIDI_KEYER_DIT,14, 1, 1 },	// should be pin 18, wiring FU
  { switch_key, ring1, 1, MIDI_KEYER_DAH,19, 1, 1 },	// should be in sequence with 2 preceding
  { switch_key, ring2, 1, MIDI_KEYER_AUX,20, 1, 1 },
  { touch_key,  other, 1, MIDI_KEYER_DIT,15, 1, 1, 500 },
  { touch_key,  other, 1, MIDI_KEYER_DAH,16, 1, 1, 500 },
};
#define n_keys (sizeof(key)/sizeof(key[0]))

static inline int touch_read(struct key *kp) {
  int v = touchRead(kp->pin);
  kp->raw_touch_level = v;
  kp->raw_touch_level_max = max(v, kp->raw_touch_level_max);
  kp->raw_touch_level_min = min(v, kp->raw_touch_level_min);
  kp->raw_touch_level_sum += v;
  kp->raw_touch_level_n += 1;
  kp->touch_level = 1000*(v-kp->raw_touch_level_min)/(kp->raw_touch_level_max-kp->raw_touch_level_min);    return kp->key;
  if (kp->key != 0) {
    /* is off, active low */
    return kp->touch_level > kp->touch_threshold;
  } else {
    /* is on */
    return kp->touch_level <= kp->touch_threshold;
  }
}
static inline void touch_key_stats(struct key *kp) {
  Serial.print(" raw "); Serial.print(kp->raw_touch_level);
  Serial.print(" max "); Serial.print(kp->raw_touch_level_max);
  Serial.print(" min "); Serial.print(kp->raw_touch_level_min);
  Serial.print(" sum "); Serial.print(kp->raw_touch_level_sum);
  Serial.print(" n "); Serial.print(kp->raw_touch_level_n);
  Serial.println();


}

static inline void touch_stats(void) {
  Serial.print("dit: "); touch_key_stats(&key[8]);
  Serial.print("dah: "); touch_key_stats(&key[9]);
}
static inline int digital_read(struct key *kp) {
  return digitalRead(kp->pin);
}

static inline void keysetup() {
  for (unsigned i = 0; i < n_keys; i += 1) {
    switch (key[i].type) {
    case ground:
      pinMode(key[i].pin, OUTPUT);
      digitalWrite(key[i].pin, LOW);
      break;
    case switch_key:
      pinMode(key[i].pin, INPUT_PULLUP);
      key[i].key = digital_read(&key[i]);
      break;
    case touch_key:
      key[i].raw_touch_level_min = 0xffffff;
      key[i].raw_touch_level_max = 0;
      key[i].raw_touch_level_sum = 0;
      key[i].raw_touch_level_n = 0;
      key[i].key = touch_read(&key[i]);
      break;
    case output_active_high:
      pinMode(key[i].pin, OUTPUT);
      digitalWrite(key[i].pin, LOW);
      break;
    case output_active_low:
      pinMode(key[i].pin, OUTPUT);
      digitalWrite(key[i].pin, HIGH);
      break;
    }
  }
  // test for switched_key on
  for (unsigned i = 0; i < n_keys; i += 1) {
    if (key[i].type == switch_key && key[i].key == 0) {
    }
  }
  /* test for stuck keys and for startup with keys held on */
  /* the ring2 switches will be grounded if a TRS plug is used */
  /* the ring1 and ring2 switches will be grounded if a TS plug is used */
}

static inline void keyloop() {
  uint32_t current_time = micros();
  for (unsigned i = 0; i < n_keys; i += 1) {
    if ( ! key[i].enabled ||
	 key[i].type == ground ||
	 key[i].type == output_active_low ||
	 key[i].type == output_active_high)
      continue;

    const int new_key = 
      key[i].type == switch_key ? digital_read(&key[i]) :
      key[i].type == touch_key ? touch_read(&key[i]) :
      key[i].key;

    if (new_key != key[i].key && 
	(key[i].transition_time == 0 ||
	 current_time-key[i].transition_time >= key[i].transition_timeout)) {
      key[i].transition_time = current_time;
      usbMIDI.sendNoteOn(key[i].note, new_key != 0 ? 0 : 1, key[i].channel);
      usbMIDI.send_now();
      key[i].key = new_key;
    }
  }
}

// optional timing loop, reports usec per loop average
// every 5 seconds via Serial.println()
// #define TIMING 1
#ifdef TIMING
double average_micros_per_loop;
long last_micros;

long loop_counter;

void timingsetup() {
  Serial.begin(9600);
  average_micros_per_loop = 0;
  last_micros = micros();
  loop_counter = 0;
}
static inline void timingloop() {
  if (++loop_counter >= 1024) {
    long now_micros = micros();
    average_micros_per_loop += (double)(now_micros - last_micros) / (double)loop_counter;
    average_micros_per_loop /= 2;
    last_micros = now_micros;
    loop_counter = 0;
    Serial.println(average_micros_per_loop);
  }
}
#else
// nil timing loop
void timingsetup() {}
void timingloop() {}
#endif
  
void setup() {
  // setup the key pins
  keysetup();
  // set up the loop timing
  timingsetup();
}

void loop() {
  // read and process input switches
  keyloop();
  // discard incoming MIDI messages.
  while (usbMIDI.read());
  // serial read
  switch (Serial.read()) {
    case '?': touch_stats(); break;
    case '\n': break;
    default: break;
  }
  // time the loop
  timingloop();
}
