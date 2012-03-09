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

/* Softrock to USB MIDI

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

   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.

   This sketch connects to the Softrock Ensemble RX II or Ensemble RXTX
   with a ribbon cable to an 8 pin dip.

   Six of the pins are connected to the Teensy:

   1 - PF6 pin 17 - paddle TIP - FL Sel 1
   2 - PD0 pin 5 - SCL
   3 - PF7 pin 16 - /PTT - FL Sel 0
   4 - GND 
   5 - 
   6 - PD1 pin 6 - SDA, paddle RING - 
   7 -
   8 - VCC +5V

   The unconnected pins go to the Softrock USB connector which is not used
   and should not be connected.  The USB connector on the Teensy is used and
   power is supplied through the USB cable.

*/

#include "WProgram.h"
#include <Wire.h>

#include "midi.h"
#include "midikeysr.h"

device_type_t device= no_device;

// the MIDI channel used for transferring MIDI note_on/off events
const int channel = 1;		// the MIDI channel number
const int base_note = 0;	// the base midi note

// common assignments
const int sclPin = 5;		// I2C clock pin, is D0
const int sdaPin = 6;		// I2C data pin, is D1

// RXTX assignments
const int dahPin = 6;		// the dah pin number, is D1
const int ditPin = 7;		// the dit pin number, is D2
const int pttPin = 8;		// /ptt on D3

// RX assignments
const int fl1Pin = 7;		// FL SEL 1 on D2
const int fl0Pin = 8;		// FL SEL 0 on D3

const int readPeriod = 100;	// usec between pin samples
byte dit;			// the current dit value
byte dah;			// the current dah value

//===================================================================
//	MC9S08QG8 IIC Subroutines	3/1/2008
//	Written by John H. Fisher - K5JHF
//===================================================================
char i2c_read(char slave_address, char reg_address) {
  Wire.beginTransmission(slave_address);
  Wire.send(reg_address);
  Wire.endTransmission();
  Wire.requestFrom(slave_address, 1);
  return  Wire.receive();
}

void i2c_write(char slave_address, char reg_address, char data) {
  Wire.beginTransmission(slave_address);
  Wire.send(reg_address);
  Wire.send(data);
  Wire.endTransmission();
}

void i2c_write_N(char slave_address, char reg_address, unsigned char write_data[], char N ) {
  char	i;
}

// setup pins for rxtx
void setup_rxtx() {
  pinMode(ditPin, INPUT_PULLUP);
  pinMode(dahPin, INPUT_PULLUP);
  pinMode(pttPin, OUTPUT);
  dit = digitalRead(ditPin);
  dah = digitalRead(dahPin);
  digitalWrite(pttPin, HIGH);	// /ptt
}

// setup pins for rx
void setup_rx() {
  pinMode(fl0Pin, OUTPUT);
  pinMode(fl1Pin, OUTPUT);
  digitalWrite(fl0Pin, LOW);
  digitalWrite(fl1Pin, LOW);
}

// handle incoming note off messages
void handleNoteOff(uint8_t note, uint8_t velocity) {
  switch (note) {
  case 4: case 9: case 10: case 12: case 14: case 15:
    // treat these as PWM outputs until further notice
    analogWrite(note, 0); break;
  default:
    // treat everything else as digital outputs
    digitalWrite(note, LOW); break;
  }
}

// handle incoming note on messages
void handleNoteOn(uint8_t note, uint8_t velocity) {
  switch (note) {
  case 4: case 9: case 10: case 12: case 14: case 15:
    // treat these as PWM outputs until further notice
    analogWrite(note, velocity*2); break;
  default:
    // treat everything else as digital outputs
    digitalWrite(note, HIGH); break;
  }
}

// handle incoming system exclusive messages
void handleSysEx(uint8_t nbytes, uint8_t *bytes) {
  if (nbytes & 1) {
    const static unsigned char msg[] = "}!odd length sysex";
    usbMIDI.sendSysex(sizeof(msg), msg);
  } else if (nbytes < 6) {
    const static unsigned char msg[] = "}!short sysex";
    usbMIDI.sendSysex(sizeof(msg), msg);
  } else if (bytes[0] != MIDI_SYSEX_VENDOR) {
    const static unsigned char msg[] = "}!unknown vendor";
    usbMIDI.sendSysex(sizeof(msg), msg);
  } else if (bytes[1] != '!') {
    const static unsigned char msg[] = "}!unknown prefix";
    usbMIDI.sendSysex(sizeof(msg), msg);
  } else {
    // convert from nibbles to bytes
    bytes += 2;
    nbytes -= 2;
    for (int i = 0, j = 0; i < nbytes; i += 2, j += 1)
      bytes[j] = ((bytes[i]-'0')<<4) | (bytes[i+1]-'0');
    nbytes /= 2;
    switch (bytes[0]) {
    default: {
      const static uint8_t msg[] = "}!unimplemented operation"; 
      usbMIDI.sendSysex(sizeof(msg), msg);
      break;
    }
    //case MIDIKEYSR_I2C_SCAN: /* scan i2c bus for actives, return bit map */
    //break;
    case MIDIKEYSR_I2C_SEND: /* send i2c address, value, ... */
      Wire.beginTransmission(bytes[1]);
      for (int i = 2; i < nbytes; i += 1) Wire.send(bytes[i]);
      Wire.endTransmission();
      break;
    case MIDIKEYSR_I2C_RECV: /* recv i2c address, register, ... */
      for (i = 2, i < nbytes; i += 1) bytes[i] = i2c_read(bytes[1], bytes[i]);
      replySysEx(nbytes-2, &bytes[2]);
      break;
    case MIDIKEYSR_SI570_FREEZE_DCO:
      i2c_write(0x55, 137, i2c_read ( 0x55, 137 ) | 0x10 );
      break;
    case MIDIKEYSR_SI570_UNFREEZE_DCO: /*  */
      i2c_write(0x55, 137, i2c_read ( 0x55, 137 ) & ~0x10 );
      break;
    case MIDIKEYSR_SI570_NEW_FREQ: /*  */
      i2c_write( 0x55, 135, i2c_read ( 0x55, 135 ) | 0x40 );
      while (  i2c_read ( 0x55, 135 ) & 0x40 );
      break;
    case MIDIKEYER_SI570_RECALL_F0: /*  */
      i2c_write ( 0x55, 135, i2c_read ( 0x55, 135 ) | 0x01 );
      while (  i2c_read ( 0x55, 135 ) & 0x01 );
      break;
    }
  }
}

// handle input pin change dispatching
void handleInputs() {
  if (device == rxtx_device) {
    byte new_dit = digitalRead(ditPin);
    if (new_dit != dit) {
      if ((dit = new_dit) != 0) {
	usbMIDI.sendNoteOff(base_note+0, 0, channel);
      } else {
	usbMIDI.sendNoteOn(base_note+0, 99, channel);
      }
    }
    byte new_dah = digitalRead(dahPin);
    if (new_dah != dah) {
      if ((dah = new_dah) != 0) {
	usbMIDI.sendNoteOff(base_note+1, 0, channel);
      } else {
	usbMIDI.sendNoteOn(base_note+1, 99, channel);
      }
    }
  }
}

// setup
void setup() {
}

// loop until done
void loop() {
  // dispatch incoming MIDI messages
  if (usbMIDI.read(channel)) {
    switch usbMIDI.getType() {
      case 0: handleNoteOff(usbMIDI.getData1(), usbMIDI.getData2()); break;
      case 1: handleNoteOn(usbMIDI.getData1(), usbMIDI.getData2()); break;
      case 7: handleSysEx(usbMIDI.getData1(), usbMIDI.getSysExArray()); break;
      }
  }
  // look for input events to send
  static long last_read;
  long now = micros();
  if (now-last_read >= readPeriod) {
    last_read = now;
    handleInputs();
  }
  // flush any output generated
  usbMIDI.send_now();
}

