/*
             LUFA Library
     Copyright (C) Dean Camera, 2011.

  dean [at] fourwalledcubicle [dot] com
           www.lufa-lib.org
*/

/*
  Copyright 2011  Dean Camera (dean [at] fourwalledcubicle [dot] com)

  Permission to use, copy, modify, distribute, and sell this
  software and its documentation for any purpose is hereby granted
  without fee, provided that the above copyright notice appear in
  all copies and that both that the copyright notice and this
  permission notice and warranty disclaimer appear in supporting
  documentation, and that the name of the author not be used in
  advertising or publicity pertaining to distribution of the
  software without specific, written prior permission.

  The author disclaim all warranties with regard to this
  software, including all implied warranties of merchantability
  and fitness.  In no event shall the author be liable for any
  special, indirect or consequential damages or any damages
  whatsoever resulting from loss of use, data or profits, whether
  in an action of contract, negligence or other tortious action,
  arising out of or in connection with the use or performance of
  this software.
*/

/** \file
 *
 *  Main source file for the MIDI demo. This file contains the main tasks of
 *  the demo and is responsible for the initial application hardware configuration.
 */

#include "MIDI.h"

/** LUFA MIDI Class driver interface configuration and state information. This structure is
 *  passed to all MIDI Class driver functions, so that multiple instances of the same class
 *  within a device can be differentiated from one another.
 */
USB_ClassInfo_MIDI_Device_t Keyboard_MIDI_Interface = {
  .Config = {
    .StreamingInterfaceNumber = 1,

    .DataINEndpointNumber      = MIDI_STREAM_IN_EPNUM,
    .DataINEndpointSize        = MIDI_STREAM_EPSIZE,
    .DataINEndpointDoubleBank  = false,

    .DataOUTEndpointNumber     = MIDI_STREAM_OUT_EPNUM,
    .DataOUTEndpointSize       = MIDI_STREAM_EPSIZE,
    .DataOUTEndpointDoubleBank = false,
  },
};


/** Main program entry point. This routine contains the overall program flow, including initial
 *  setup of all components and the main program loop.
 */
int main(void) {
  SetupHardware();

  LEDs_SetAllLEDs(LEDMASK_USB_NOTREADY);
  sei();

  for (;;) {
    CheckPaddleMovement();

    MIDI_EventPacket_t ReceivedMIDIEvent;
    while (MIDI_Device_ReceiveEventPacket(&Keyboard_MIDI_Interface, &ReceivedMIDIEvent)) {
      if ((ReceivedMIDIEvent.Command == (MIDI_COMMAND_NOTE_ON >> 4)) && (ReceivedMIDIEvent.Data3 > 0))
	LEDs_SetAllLEDs(ReceivedMIDIEvent.Data2 > 64 ? LEDS_LED1 : LEDS_LED2);
      else
	LEDs_SetAllLEDs(LEDS_NO_LEDS);
    }

    MIDI_Device_USBTask(&Keyboard_MIDI_Interface);
    USB_USBTask();
  }
}

/** Configures the board hardware and chip peripherals for the demo's functionality. */
void SetupHardware(void) {
  /* Disable watchdog if enabled by bootloader/fuses */
  MCUSR &= ~(1 << WDRF);
  wdt_disable();

  /* Disable clock division */
  clock_prescale_set(clock_div_1);

  /* Hardware Initialization */
  // Joystick_Init();
  // set all PORTB pins for input with pullups
  DDRB &= ~(0xFF);
  PORTB |= 0xFF;
  // LEDs_Init();
  // set all PORTD pins for output
  DDRD |= 0xFF;
  PORTD &= ~(0xFF);
  // Buttons_Init();
  // used PORTB for buttons, too
  USB_Init();
}

uint8_t Paddles_GetStatus(void) { return PINB; }
#define PADDLE_DIT	0x01	/* PB0 for dit paddle */
#define PADDLE_DAH	0x02	/* PB1 for dah paddle */

uint8_t Buttons_GetStatus(void) { return PINB; }

#define BUTTONS_BUTTON1 0x80	/* PB7 for button1 */

/** Send a midi note on/off command, return success **/
int MIDISend(uint8_t MIDICommand, uint8_t Channel, uint8_t MIDIPitch) {
  MIDI_EventPacket_t MIDIEvent = (MIDI_EventPacket_t) {
    .CableNumber = 0,
    .Command     = (MIDICommand >> 4),
    .Data1       = MIDICommand | Channel,
    .Data2       = MIDIPitch,
    .Data3       = MIDI_STANDARD_VELOCITY,
  };

  if (MIDI_Device_SendEventPacket(&Keyboard_MIDI_Interface, &MIDIEvent) == ENDPOINT_RWSTREAM_NoError) {
    MIDI_Device_Flush(&Keyboard_MIDI_Interface);
    return 1;
  } else {
    MIDI_Device_Flush(&Keyboard_MIDI_Interface);
    return 0;
  }
}

/** Checks for changes in the position of the board joystick, sending MIDI events to the host upon each change. */
void CheckPaddleMovement(void) {
  /* previous status and turn counter */
  static uint8_t PrevDitStatus, PrevDahStatus, WhoseTurn;

  /* Get current paddle mask, XOR with previous to detect paddle changes */
  uint8_t PaddleStatus  = Paddles_GetStatus();

  if (WhoseTurn ^= 1) {
    /* Process the Dit paddle on this round */
    uint8_t NewDitStatus = ((PaddleStatus&PADDLE_DIT) != 0);
    if (NewDitStatus ^ PrevDitStatus) {
      if (MIDISend(NewDitStatus ? MIDI_COMMAND_NOTE_OFF : MIDI_COMMAND_NOTE_ON, MIDI_CHANNEL(1), 0))
	PrevDitStatus = NewDitStatus;
      else {
	// stall, wait for the interface to start working again
	WhoseTurn ^= 1;
      }
    }
  } else {
    /* Process the Dah paddle on this round */
    uint8_t NewDahStatus = ((PaddleStatus&PADDLE_DAH) != 0);
    if (NewDahStatus ^ PrevDahStatus) {
      if (MIDISend(NewDahStatus ? MIDI_COMMAND_NOTE_OFF : MIDI_COMMAND_NOTE_ON, MIDI_CHANNEL(1), 1))
	PrevDahStatus = NewDahStatus;
      else {
	// stall, wait for the interface to start working again
	WhoseTurn ^= 1;
      }
    }
  }
}

/** Event handler for the library USB Connection event. */
void EVENT_USB_Device_Connect(void) {
  LEDs_SetAllLEDs(LEDMASK_USB_ENUMERATING);
}

/** Event handler for the library USB Disconnection event. */
void EVENT_USB_Device_Disconnect(void) {
  LEDs_SetAllLEDs(LEDMASK_USB_NOTREADY);
}

/** Event handler for the library USB Configuration Changed event. */
void EVENT_USB_Device_ConfigurationChanged(void) {
  bool ConfigSuccess = true;

  ConfigSuccess &= MIDI_Device_ConfigureEndpoints(&Keyboard_MIDI_Interface);

  LEDs_SetAllLEDs(ConfigSuccess ? LEDMASK_USB_READY : LEDMASK_USB_ERROR);
}

/** Event handler for the library USB Control Request reception event. */
void EVENT_USB_Device_ControlRequest(void) {
  MIDI_Device_ProcessControlRequest(&Keyboard_MIDI_Interface);
}

