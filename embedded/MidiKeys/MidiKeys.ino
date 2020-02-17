/*
  Copyright (C) 2019 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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

   To use it, you need:/*
  Copyright (C) 2019 by Roger E Critchlow Jr, Santa Fe, NM, USA.

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
   open as a MIDI device may be problematic.

  Wiring is simple.  Insert a Teensy LC with pins into breadboard.
  insert breadboard friendly stereo jacks into breadboard.  As you
  face one of these stereo jacks, the tip signal is on the rightmost
  pin, the ring signal is on the leftmost pin, and the grounded shield
  is on the middle pin.  The tip pin on your first stereo jack wires to 
  Teensy pin 0, the ring pin wires to Teensy pin 1, and the grounded 
  shield pin wires to a Teensy ground pin.  The second stereo jack wires
  to Teensy pins 2, 3, and ground.  And so on, the tips go to even pins,
  the rings go to the adjacent odd pin, and the grounds go to ground.
  Use Teensy pins 0 through 23 for up to twelve stereo jacks.  This is
  enabled with DENSE_LAYOUT.

  Even simpler wiring, insert Teensy into solderless breadboard off with
  zero, one, three, and four sockets exposed, the usb socket goes at the
  zero socket edge.  Then insert one or two breadboard friendly stereo
  jacks on the edge with four pins exposed, so the first socket lines up
  with pins 0-4, and the second socket lines up with pins 5-9.  No jumpers
  required.  This is enabled with SIMPLE_LAYOUT.
  
  Features to add:
  separate debounceFor for each key
  adjust debounceFor with MIDI command
  adjust channel with MIDI command
  adjust base_note with MIDI command

*/

#define DENSE_LAYOUT 0
#define SIMPLE_LAYOUT 1

#include "WProgram.h"
#include "debouncer.h"

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

// main purpose
const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note
const int base_pin = 0;     // the base pin number
//const int n_jacks = 12;     // the number of stereo jacks
const int n_jacks = 2;
const int n_keys = 2*n_jacks;

const byte debounceFor = 4;  // 16 clock debounce

byte keyNote[n_keys];
byte keyPin[n_keys];
byte key[n_keys];            // the current key value
debouncer filter[n_keys];    // the current debounce filter

static inline void keysetup() {
#if DENSE_LAYOUT
  for (int i = 0; i < n_keys; i += 1) {
    keyPin[i] = base_pin + i;
    pinMode(keyPin[i], INPUT_PULLUP);
    key[i] = digitalRead(keyPin[i]);
    filter[i].setSteps(debounceFor);
    keyNote[i] = base_note + i;
  }
#endif
#if SIMPLE_LAYOUT
  for (int i = 0; i < n_jacks; i += 1) {
    const int j = i*2, k = i*2+1;
    keyPin[j] = base_pin+i*5;     // will be dah
    pinMode(keyPin[j], INPUT_PULLUP);
    key[j] = digitalRead(keyPin[j]);
    keyNote[j] = base_note + k;
    keyPin[k] = base_pin+i*5+4;   // will be dit
    pinMode(keyPin[k], INPUT_PULLUP);
    key[k] = digitalRead(keyPin[k]);
    keyNote[k] = base_note + j;
    const byte gndPin = base_pin+i*5+2;
    pinMode(gndPin, OUTPUT);
    digitalWrite(gndPin, LOW);
  }
#endif
}

static inline void keyloop() {
  for (int i = 0; i < n_keys; i += 1) {
    const byte old_key = key[i];
    const byte new_key = filter[i].debounce(digitalRead(keyPin[i])); 
    if (new_key != old_key) {
      if (new_key != 0) {
        usbMIDI.sendNoteOff(keyNote[i], 0, channel);
      } else {
        usbMIDI.sendNoteOn(keyNote[i], 99, channel);
      }
      usbMIDI.send_now();
      key[i] = new_key;
    }
  }
}

// optional timing loop, reports usec per loop average
// every 5 seconds via Serial.println()
#define TIMING 1
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
  // time the loop
  timingloop();
}
