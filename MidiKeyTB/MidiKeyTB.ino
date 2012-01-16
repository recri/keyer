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

   To use it, you need:

   1) to get a Teensy 2.0 from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   3) on Ubuntu, you will need the gcc-avr and avr-libc packages
   for Arduino to use.
   4) you may need to install the teensy loader from
   http://www.pjrc.com/teensy/loader.html, I'm not sure.

   This extended version also interfaces a Sparkfun Blackberry Trackball
   breakout board, http://www.sparkfun.com/products/9320.

   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.
*/

#include "WProgram.h"
#include "Debounce.h"

const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note

const int ditPin = 0;       // the dit pin number, is B0
const int dahPin = 1;       // the dah pin number, is B1
const int btnPin = 2;	    // button on B2

byte dit;                   // the current dit value
byte dah;                   // the current dah value
byte btn;                   // the current button value

const int debounceFor = 20; // 20 trip debounce
const int readPeriod = 50;  // microseconds per debounce trip

Debounce ditFilter(debounceFor);	    
Debounce dahFilter(debounceFor);
Debounce btnFilter(debounceFor);

const int rgtPin = 5;		// right on D0
const int lftPin = 6;		// left on D1
const int dwnPin = 7;		// down on D2
const int upPin = 8;		// up on D3

const int whtPin = 9;		// white on C6
const int grnPin = 10;		// green on C7
const int redPin = 12;		// red on B5
const int bluPin = 15;		// blue on B6

const int rgtInterrupt = 0;	// right on D0
const int lftInterrupt = 1;	// left on D1
const int dwnInterrupt = 2;	// down on D2
const int upInterrupt = 3;	// up on D3

volatile int _right_left, _down_up;
int right_left, down_up;

void incrementRight() { _right_left += 1; }
void incrementLeft() { _right_left -= 1; }
void incrementDown() { _down_up += 1; }
void incrementUp() { _down_up -= 1; }

void note_on(byte _channel, byte note, byte velocity) {
  if (channel == _channel) {
    if (note == base_note+5)
      analogWrite(whtPin, velocity*2);
    else if (note == base_note+6)
      analogWrite(grnPin, velocity*2);
    else if (note == base_note+7)
      analogWrite(redPin, velocity*2);
    else if (note == base_note+8)
      analogWrite(bluPin, velocity*2);
  }
}
void note_off(byte _channel, byte note, byte velocity) {
  if (channel == _channel) {
    if (note == base_note+5)
      analogWrite(whtPin, 0);
    else if (note == base_note+6)
      analogWrite(grnPin, 0);
    else if (note == base_note+7)
      analogWrite(redPin, 0);
    else if (note == base_note+8)
      analogWrite(bluPin, 0);
  }
}

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  pinMode(btnPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
  btn = digitalRead(btnPin);
  attachInterrupt(rgtInterrupt, incrementRight, CHANGE);
  attachInterrupt(lftInterrupt, incrementLeft, CHANGE);
  attachInterrupt(dwnInterrupt, incrementDown, CHANGE);
  attachInterrupt(upInterrupt, incrementUp, CHANGE);
  usbMIDI.setHandleNoteOn(note_on);
  usbMIDI.setHandleNoteOn(note_off);
}


void loop() {
  static long last_read;
  if (micros()-last_read >= readPeriod) {
    last_read = micros();
    byte new_dit = ditFilter.debounce(digitalRead(ditPin));
    if (new_dit != dit) {
      if ((dit = new_dit) != 0) {
        usbMIDI.sendNoteOff(base_note+0, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+0, 99, channel);
      }
    }
    byte new_dah = dahFilter.debounce(digitalRead(dahPin));
    if (new_dah != dah) {
      if ((dah = new_dah) != 0) {
        usbMIDI.sendNoteOff(base_note+1, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+1, 99, channel);
      }
    }
    byte new_btn = btnFilter.debounce(digitalRead(btnPin));
    if (new_btn != btn) {
      if ((btn = new_btn) != 0) {
        usbMIDI.sendNoteOff(base_note+2, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+2, 99, channel);
      }
    }
  }
  int new_right_left = _right_left;
  if (new_right_left != right_left) {
    // base_note+3
    usbMIDI.sendNoteOn(base_note+3, 64+new_right_left-right_left, channel);
    right_left = new_right_left;
  }
  int new_down_up = _down_up;
  if (new_down_up != down_up) {
    // base_note+4
    usbMIDI.sendNoteOn(base_note+4, 64+new_down_up-down_up, channel);
    down_up = new_down_up;
  }
  usbMIDI.send_now();
  usbMIDI.read();
}

