/* -*-C++-*- */
/*
** TouchMidiKey
** Touch Key paddles that generate midi notes.
** Compile with pjrc.com Teensyduino enhanced Arduino IDE
** Specify Board: "Teensy LC" as processor
** Specify USB Type: "Serial + Midi" as USB interface
*/

static const char _file[] = __FILE__;
static const char _date[] = __DATE__;
static const char _time[] = __TIME__;

#define NPADS 2
#define PADS 15, 16

#include "Config.h"
#include "TouchPads.h"
#include "TouchMonitor.h"

#if FLASH_LED
#define setupLED()	pinMode(13, OUTPUT)
#define setLED(value)	digitalWrite(13, value); }
#else
#define setupLED()	/* nil */
#define setLED(v)	/* nil */
#endif

uint8_t pads[NPADS] = { PADS };

const uint8_t channel = 1;      // the MIDI channel number to send messages
const uint8_t base_note = 0;    // the base midi note

void setup()
{                
  Serial.begin(38400);
  setupLED();
  TouchPads::begin(NPADS, pads);
  TouchPads::set_threshold(0x40);
}

void loop() {
  monitor();
  static uint32_t last_clock = 0;
  static uint8_t last_value[NPADS];
  
  if (TouchPads::clock() != last_clock) {
    uint8_t do_send = 0;
    last_clock = TouchPads::clock();
    for (int i = 0; i < NPADS; i += 1) {
      if (TouchPads::value(i) != last_value[i]) {
	last_value[i] ^= 1;
	do_send += 1;
	if (last_value[i] == 0)
	  usbMIDI.sendNoteOff(base_note+i, 0, channel);
	else
	  usbMIDI.sendNoteOn(base_note+i, 99, channel);
      }
    }
    if (do_send)
      usbMIDI.send_now();
  }
  setLED((millis() & 256) != 0);
}
