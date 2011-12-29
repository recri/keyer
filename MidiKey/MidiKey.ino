/* Iambic paddle to USB MIDI

   You must select MIDI from the "Tools > USB Type" menu

   This example code is in the public domain.
   
   This is a trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.

   To use it, you need:

   1) to get a Teensy 2.0 from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   3) on Ubuntu, you need the gcc-avr and avr-libc packages
   4) you may need to install the teensy loader from
   http://www.pjrc.com/teensy/loader.html, I'm not sure.

   I am experiencing some stuck keys for which I suspect the
   Bounce library.  My experience with my Bencher paddle on
   another Arduino project was that algorithmic debouncing was
   a waste of time, the paddle is mechanically and electrically
   designed to not bounce.
   
   The Bounce library has been modified to accept a microsecond
   interval.
   
   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.
*/

#include "WProgram.h"
#include "Bounce.h"

// the MIDI channel number to send messages
const int channel = 1;
// the base midi note
const int base_note = 0;
// the microseconds to debounce
const int debounce = 50;

// Create Bounce objects for each button.  The Bounce object
// automatically deals with contact chatter or "bounce", and
// it makes detecting changes very simple.
Bounce button0 = Bounce(0, debounce);
Bounce button1 = Bounce(1, debounce);

void setup() {
  // Configure the pins for input mode with pullup resistors.
  // The pushbuttons connect from each pin to ground.  When
  // the button is pressed, the pin reads LOW because the button
  // shorts it to ground.  When released, the pin reads HIGH
  // because the pullup resistor connects to +5 volts inside
  // the chip.  LOW for "on", and HIGH for "off" may seem
  // backwards, but using the on-chip pullup resistors is very
  // convenient.  The scheme is called "active low", and it's
  // very commonly used in electronics... so much that the chip
  // has built-in pullup resistors!
  pinMode(0, INPUT_PULLUP);
  pinMode(1, INPUT_PULLUP);
}

void loop() {
  // Update all the buttons.  There should not be any long
  // delays in loop(), so this runs repetitively at a rate
  // faster than the buttons could be pressed and released.
  if (button0.update()) {
    if (button0.read()) {
      usbMIDI.sendNoteOff(base_note+0, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+0, 99, channel);
    }
  }
  if (button1.update()) {
    if (button1.read()) {
      usbMIDI.sendNoteOff(base_note+1, 0, channel);
    } else {
      usbMIDI.sendNoteOn(base_note+1, 99, channel);
    }
  }
}

