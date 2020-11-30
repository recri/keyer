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

/* LCMidiKey - Low Commitment MIDI Key
   Iambic paddles to USB MIDI
   See "low-commintment2.png" in this directory

   This is a very trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.  At
   least it was once upon a time.

   To use it, you need:

   1) A Teensy LC from http://www.pjrc.com/teensy/, or http://www.adafruit.com/products/199,
   or amazon.com, avoid counterfeits.
   2) 2x 14 header pins soldered into the Teensy long edges
   3) A small solderless breadboard.
   4) A breadboard friendly stereo jack, such as https://www.adafruit.com/product/1699
   5) Plug the Teensy LC pins into the breadboard off center
   6) Plug the stereo jack into the breadboard so the jack pins
   align to pins 0,1,2,3,4 on the Teensy
   7) Connect the Teensy LC to your computer with a USB cable
   8) Connect the stereo jack to your paddle with a stereo cable.
   9) Follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   10) Start Arduino, 
   11) choose Teensy LC from the device menu
   12) specify MIDI as the device type
   13) Compile and download this sketch.
   14) Connect the LCMidiKey device to your keyer software.
*/

#include <WProgram.h>

///
/// key handling
///
static elapsedMicros time0, time4;
static byte key0, key4;
static const byte note0 = 1, note4 = 0, channel = 1;

void setup() {
  time0 = 0;
  pinMode(0, INPUT_PULLUP);
  key0 = digitalRead(0);

  pinMode(2, OUTPUT);
  digitalWrite(2, LOW);

  time4 = 0;
  pinMode(4, INPUT_PULLUP);
  key4 = digitalRead(4);
}

void loop() {
  while (usbMIDI.read());
  if (time0 > 1000) {
    const byte new_key = digitalRead(0);
    if (new_key != key0) {
      time0 = 0;
      key0 = new_key;
      usbMIDI.sendNoteOn(note0, key0 != 0 ? 0 : 1, channel);
      usbMIDI.send_now();
    }
  }
  if (time4 > 1000) {
    const byte new_key = digitalRead(4);
    if (new_key != key4) {
      time4 = 0;
      key4 = new_key;
      usbMIDI.sendNoteOn(note4, key4 != 0 ? 0 : 1, channel);
      usbMIDI.send_now();
    }
  }
}
