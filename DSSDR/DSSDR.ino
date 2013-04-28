/* -*- mode: c++; tab-width: 8 -*- */
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

/* Dirt Simple SDR - Softrock as USB MIDI/AUDIO device

   You must select MIDI from the "Tools > USB Type" menu
   (In time it should be AUDIO/MIDI.)

   To use it, you need:

   1) to get a Teensy 3.0 from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/1044 or
   https://www.sparkfun.com/products/11780.
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html
   3) you may need to install the teensy loader from
   http://www.pjrc.com/teensy/loader.html, I'm not sure, it might
   come along with teensyduino.

   Do not reprogram your Teensy while ALSA and Jack have the MidiKey
   open as a MIDI device or you will get some system crashes.

   This sketch has the Teensy connected to an SR63ng and miscellaneous
   other stuff.  It's a prototype for the DSSDR (Dirt Simple Software
   Defined Radio).  (It all should be adaptable to Softrock Ensemble RX II
   and Ensemble RXTX, but I haven't worked that out.)
   
   The pins connected to the Teensy are a work in progress.
   
   0 - There isn't, but ought to be, a single ground bus for the Teensy
       a) a ground connection to the SR63ng on the I2C connector
       b) a ground connection to the key jack common
   1 - SCL = A5 = 19
   2 - SDA = A4 = 18
   3 - PTT_IN = A3 = 17 (input to SR63ng, output from Teensy)
   4 - PTT_OUT = A2 = 16 (output from SR63ng, input to Teensy)
   5 - KEY_RGT = A1 = 15 (from stereo jack, pullup)
   6 - KEY_LFT = A0 = 14 (from stereo jack, pullup)

*/

#include "WProgram.h"
#include <Wire.h>

#include "midi.h"
#include "dssdr.h"

device_type_t device= no_device;

// the MIDI channel used for transferring MIDI note_on/off events
const uint8_t channel = 1;	// the MIDI channel number
const uint8_t base_note = 0;	// the base midi note

// common assignments
const uint8_t sclPin = 5;	// I2C clock pin, is D0
const uint8_t sdaPin = 6;	// I2C data pin, is D1

// RXTX assignments
const uint8_t dahPin = 6;	// the dah pin number, is D1
const uint8_t ditPin = 17;	// the dit pin number, is F6
const uint8_t pttPin = 16;	// /ptt on F7

// RX assignments
const uint8_t fl1Pin = 17;	// FL SEL 1 on F6
const uint8_t fl0Pin = 16;	// FL SEL 0 on F7

const uint8_t readPeriod = 100;	// usec between pin samples
uint8_t dit;			// the current dit value
uint8_t dah;			// the current dah value

//===================================================================
//	MC9S08QG8 IIC Subroutines	3/1/2008
//	Written by John H. Fisher - K5JHF
//===================================================================
void i2c_put(uint8_t slave_address, uint8_t reg_address, uint8_t data) {
  Wire.beginTransmission(slave_address);
  Wire.send(reg_address);
  Wire.send(data);
  Wire.endTransmission();
}

uint8_t i2c_get(uint8_t slave_address, uint8_t reg_address) {
  Wire.beginTransmission(slave_address);
  Wire.send(reg_address);
  Wire.endTransmission();
  Wire.requestFrom((int)slave_address, (int)1);
  return  Wire.receive();
}

void i2c_write(uint8_t slave_address, uint8_t nbytes, uint8_t *bytes) {
  Wire.beginTransmission(slave_address);
  Wire.send(bytes, nbytes);
  Wire.endTransmission();
}

void i2c_read(uint8_t slave_address, uint8_t nbytes, uint8_t *bytes) {
  for (uint8_t i = 0; i < nbytes; i += 1) bytes[i] = i2c_get(slave_address, bytes[i]);
}

uint8_t i2c_probe(uint8_t slave_address) {
  Wire.beginTransmission(slave_address);
  Wire.send(slave_address);
  Wire.send(0);
  return Wire.endTransmission(); // 0 success, 1 too many bytes, 2 NACK on address, 3 NACK on transmission
}
  
/*
** device specific set up
*/
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

uint8_t device_init(device_type_t dev) {
  switch (dev) {
  case no_device:
    device = dev;
    return 1;
  case rx_device:
    setup_rx();
    device = dev;
    return 1;
  case rxtx_device:
    setup_rxtx();
    device = dev;
    return 1;
  default:
    return 0;
  }
}

/*
** sysex decoding and encoding
** MIDI only allows 7 bit characters in messages
*/
void sysExDecode(uint8_t nbytes, uint8_t *ibytes, uint8_t *obytes) {
  for (uint8_t i = 0; i < nbytes; i += 2) {
    *obytes = (*ibytes++ - 'a');
    *obytes <<= 4;
    *obytes++ |= (*ibytes++ - 'a');
  }
}

void sysExEncode(uint8_t nbytes, uint8_t *ibytes, uint8_t *obytes) {
  for (uint8_t i = 0; i < nbytes; i += 1) {
    *obytes++ = 'a'+((*ibytes>>4)&0xf);
    *obytes++ = 'a'+(*ibytes++&0xf);
  }
  *obytes = 0;
}

void sysExEncodeString(char *ibytes, uint8_t *obytes) {
  sysExEncode(strlen(ibytes), (uint8_t *)ibytes, obytes);
}

/*
** midi event handling
*/
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
void handleSysEx(uint8_t n, uint8_t *ibuff) {
  uint8_t obuff[MAX_SYSEX+4];
  obuff[0] = MIDI_SYSEX;	// start SysEx output wrapper
  obuff[1] = MIDI_SYSEX_VENDOR;	// start SysEx vendor
  obuff[2] = '!';		// start SysEx prefix
  ibuff += 1;			// skip SysEx wrapper
  n -= 2;			// skip SysEx wrapper
  if (n & 1) {
    sysExEncodeString("odd?", obuff+3);	// 
  } else if (n < 2) {
    sysExEncodeString("short?", obuff+3); // 
  } else if (n > MAX_SYSEX) {
    sysExEncodeString("long?", obuff+3); // 
  } else if (ibuff[0] != MIDI_SYSEX_VENDOR) {
    sysExEncodeString("vendor?", obuff+3); // 
  } else if (ibuff[1] != '!') {
    sysExEncodeString("prefix?", obuff+3); // 
  } else if (n == 2) {
    sysExEncodeString("00.00", obuff+3); // identify version
  } else if (n < 6) {
    sysExEncodeString("short?", obuff+3); // 
  } else {
    // convert from nibbles to bytes in place
    sysExDecode(n-2, ibuff+2, ibuff);
    n = (n-2)/2;
    switch (ibuff[0]) {
    case DS_SET_DEVICE:
      if (n != 2)
        sysExEncodeString("short?", obuff+3);
      else if (device_init((device_type_t)ibuff[1]))
	sysExEncodeString("ok", obuff+3);
      else
	sysExEncodeString("device?", obuff+3);
      break;
    case DS_I2C_PROBE: /* probe i2c address */
      if (n != 2)
        sysExEncodeString("short?", obuff+3);
      else switch (i2c_probe(ibuff[1])) {
        case 0: sysExEncodeString("ok", obuff+3); break;
        case 2: sysExEncodeString("nak", obuff+3); break;
        case 3: sysExEncodeString("nak", obuff+3); break;
        case 4: sysExEncodeString("err", obuff+3); break;
        default: sysExEncodeString("unk", obuff+3); break;
      }
      break;
    case DS_I2C_SEND: /* send i2c address, value, ... */
      i2c_write(ibuff[1], n-2, ibuff+2);
      sysExEncodeString("ok", obuff+3);
      break;
    case DS_I2C_RECV: /* recv i2c address, register, ... */
      i2c_read(ibuff[1], n-2, ibuff+2);
      sysExEncode(n-2, ibuff+2, obuff+3);
      break;
    case DS_SI570_FREEZE_DCO:
      i2c_put(0x55, 137, i2c_get(0x55, 137) | 0x10);
      sysExEncodeString("ok", obuff+3);
      break;
    case DS_SI570_UNFREEZE_DCO: /*  */
      i2c_put(0x55, 137, i2c_get(0x55, 137) & ~0x10);
      sysExEncodeString("ok", obuff+3);
      break;
    case DS_SI570_NEW_FREQ: /*  */
      i2c_put(0x55, 135, i2c_get(0x55, 135) | 0x40);
      while (i2c_get(0x55, 135) & 0x40);
      sysExEncodeString("ok", obuff+3);
      break;
    case MIDIKEYER_SI570_RECALL_F0: /*  */
      i2c_put(0x55, 135, i2c_get(0x55, 135) | 0x01);
      while (i2c_get(0x55, 135) & 0x01);
      sysExEncodeString("ok", obuff+3);
      break;
    default:
      sysExEncodeString("op?", obuff+3);
      break;
    }
  }
  n = strlen((char *)obuff);
  obuff[n++] = MIDI_SYSEX_END;
  usbMIDI.sendSysEx(n, obuff);
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
  Wire.begin();
}

// loop until done
void loop() {
  // dispatch incoming MIDI messages
  if (usbMIDI.read(channel)) {
    switch (usbMIDI.getType()) {
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

