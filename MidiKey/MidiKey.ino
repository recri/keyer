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
#include "Debounce.h"
#include <avr/io.h>
#include <avr/interrupt.h>

const int channel = 1;      // the MIDI channel number to send messages
const int base_note = 0;    // the base midi note

const int ditPin = 0;       // the dit pin number, is B0
const int ditMask = 1;      // the dit bit in PORT
const int dahPin = 1;       // the dah pin number, is B1
const int dahMask = 2;      // the dah bit in PORT

const int debounce_steps = 2;
const int sample_period = 200;

byte dit;                   // the current dit value
byte dah;                   // the current dah value

Debounce debounceDit(debounce_steps);
Debounce debounceDah(debounce_steps);

volatile byte buffer[256];  // the buffered PORT values
volatile byte wptr;         // the write pointer in buffer
volatile byte rptr;         // the read pointer in buffer

// timer interrupt, save PORTD contents
ISR(TIMER4_COMPA_vect) { buffer[wptr++] = PINB; }

// timer interrupt setup, microseconds < 256
void enable_TIMER4_COMPA(int microseconds) {
   /*
   * Set up the 10-bit timer 4.
   *
   * Timer 4 will be set up as a 10-bit phase-correct PWM (WGM10 and
   * WGM11 bits), with OC4A used as PWM output.  OC1A will be set when
   * up-counting, and cleared when down-counting (COM1A1|COM1A0), this
   * matches the behaviour needed by the STK500's low-active LEDs.
   * The timer will runn on full MCU clock (1 MHz, CS10 in TCCR1B).
   */
  TCCR4A = 0; //
  TCCR4B = 5; // in TCCR4B 4 = clk/8, 5 = clk/16, 6 = clk/32 for 2MHz, 1MHz or 500KHz clock
  TCCR4C = 0; // 
  TCCR4D = 0; //
  TCCR4E = 0; //
  TC4H = (microseconds >> 8) & 3;
  OCR4A = (microseconds & 255);
  TC4H = 0;
  TCNT4 = 0;
  TIMSK4 = _BV(OCIE4A);
}

void setup() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
  enable_TIMER4_COMPA(sample_period);
}

void loop() {
  if (rptr != wptr) {
    byte port = buffer[rptr++];
    byte new_dit = debounceDit.debounce((port & ditMask) ? 1 : 0);
    byte new_dah = debounceDah.debounce((port & dahMask) ? 1 : 0);
    if (new_dit != dit) {
      if ((dit = new_dit) != 0) {
        usbMIDI.sendNoteOff(base_note+0, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+0, 99, channel);
      }
    }
    if (new_dah != dah) {
      if ((dah = new_dah) != 0) {
        usbMIDI.sendNoteOff(base_note+1, 0, channel);
      } else {
        usbMIDI.sendNoteOn(base_note+1, 99, channel);
      }
    }
  }
}

