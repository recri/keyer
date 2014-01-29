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
/* Iambic paddle to USB MIDI

   You must select MIDI from the "Tools > USB Type" menu

   This is a very trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.

   To use it, you need:

   1) to get a Teensy 2.0 from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   3) on Ubuntu, you will need the gcc-avr and avr-libc packages
   for Arduino to use.
   4) you may need to install the teensy loader from
   http://www.pjrc.com/teensy/loader.html, I'm not sure.

   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.
*/

#include "WProgram.h"
#include "debouncer.h"

const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note

const int ditPin = 0;       // the dit pin number, is B0
const int dahPin = 1;       // the dah pin number, is B1

const int debounceFor = 4;  // four clock debounce

debouncer ditFilter(debounceFor);	    
debouncer dahFilter(debounceFor);

const int sample_period = 100;

byte dit;                   // the current dit value
byte dah;                   // the current dah value

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
}


void loop() {
  byte new_dit = ditFilter.debounce(digitalRead(ditPin));
  if (new_dit != dit) {
    if ((dit = new_dit) != 0) {
      usbMIDI.sendNoteOff(base_note+0, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+0, 99, channel);
    }
    usbMIDI.send_now();
  }
  byte new_dah = dahFilter.debounce(digitalRead(dahPin));
  if (new_dah != dah) {
    if ((dah = new_dah) != 0) {
      usbMIDI.sendNoteOff(base_note+1, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+1, 99, channel);
    }
    usbMIDI.send_now();
  }
}

