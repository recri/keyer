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

const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note
const int ditPin = 4;       // the dit pin number, is D0
const int ditInterrupt = 0; // the dit interrupt, is EXT0
const int ditMask = 1;      // the dit bit in PORTD
const int dahPin = 5;       // the dah pin number, is D1
const int dahInterrupt = 1; // the dah interrupt, is EXT1
const int dahMask = 2;      // the dah bit in PORTD

byte dit;                   // the current dit value
byte dah;                   // the current dah value

volatile byte buffer[256];  // the buffered PORTD values
volatile byte wptr;         // the write pointer in buffer
volatile byte rptr;         // the read pointer in buffer

// interrupt on dit or dah pin, save PORTD contents
void interrupt() { buffer[wptr++] = PIND; }

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
  attachInterrupt(ditInterrupt, interrupt, CHANGE);
  attachInterrupt(dahInterrupt, interrupt, CHANGE);
}

void loop() {
  while (rptr != wptr) {
    byte portd = buffer[rptr++];
    byte new_dit = (portd & ditMask) ? 1 : 0;
    byte new_dah = (portd & dahMask) ? 1 : 0;
    if (new_dit != dit) {
      dit = new_dit;
      if (dit) {
        usbMIDI.sendNoteOff(base_note+0, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+0, 99, channel);
      }
    }
    if (new_dah != dah) {
      dah = new_dah;
      if (dah) {
        usbMIDI.sendNoteOff(base_note+1, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+1, 99, channel);
      }
    }
  }
}

