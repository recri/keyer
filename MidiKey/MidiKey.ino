/* Iambic paddle to USB MIDI

   You must select MIDI from the "Tools > USB Type" menu

   This example code is in the public domain.
   
   This is a very trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.

   To use it, you need:

   1) to get a Teensy 2.0 from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   3) on Ubuntu, you will need the gcc-avr and avr-libc packages
   4) you may need to install the teensy loader from
   http://www.pjrc.com/teensy/loader.html, I'm not sure.

   I am experiencing some stuck keys for which I suspect the
   Bounce library.  My experience with my Bencher paddle on
   another Arduino project was that algorithmic debouncing was
   a waste of time, the paddle is mechanically and electrically
   designed to not bounce.
   
   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.
*/

#include "WProgram.h"

// the MIDI channel number to send messages
const int channel = 1;
// the base midi note
const int base_note = 0;
// the dit pin number
const int ditPin = 0;
// the dah pin number
const int dahPin = 1;

// the current dit value
byte dit;
// the current dah value
byte dah;

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
}


void loop() {
  if (digitalRead(ditPin) != dit) {
    if (dit ^= 1) {
      usbMIDI.sendNoteOff(base_note+0, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+0, 99, channel);
    }
  }
  if (digitalRead(dahPin) != dah) {
    if (dah ^= 1) {
      usbMIDI.sendNoteOff(base_note+1, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+1, 99, channel);
    }
  }
}

