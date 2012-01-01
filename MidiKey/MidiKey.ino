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

   The "stuck keys" are due to the midi usb interface dropping packets,
   I think the issue is that two sends in immediate proximity are too
   much for the interface to handle.  So we need to poll the paddles on
   alternate loops, and keep the polling spaced out a bit.  

   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.
*/

#include "WProgram.h"
#include "Debounce.h"
#include <avr/io.h>
#include <avr/interrupt.h>

const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note

const int ditPin = 0;       // the dit pin number, is B0
const int dahPin = 1;       // the dah pin number, is B1

const int debounce_steps = 2;
const int sample_period = 20000;

byte dit;                   // the current dit value
byte dah;                   // the current dah value

Debounce debounceDit(debounce_steps);
Debounce debounceDah(debounce_steps);

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
}


void loop() {
  static byte loop_counter = 0;
  static unsigned last_poll;
  unsigned this_poll = micros();
  if (last_poll == 0) {
    last_poll = this_poll;
    return;
  } else if ((this_poll - last_poll) < sample_period) {
     return;
  }
  last_poll = this_poll;
  if (loop_counter ^= 1) {
    byte new_dit = debounceDit.debounce(digitalRead(ditPin));
    if (new_dit != dit) {
      if ((dit = new_dit) != 0) {
        usbMIDI.sendNoteOff(base_note+0, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+0, 99, channel);
      }
    }
  } else {
    byte new_dah = debounceDah.debounce(digitalRead(dahPin));
    if (new_dah != dah) {
      if ((dah = new_dah) != 0) {
        usbMIDI.sendNoteOff(base_note+1, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+1, 99, channel);
      }
    }
  }
}

