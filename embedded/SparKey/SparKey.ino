#include <midi_serialization.h>
#include <usbmidi.h>

typedef unsigned char u8;

// See midictrl.png in the example folder for the wiring diagram,
// as well as README.md.

void sendCC(uint8_t channel, uint8_t control, uint8_t value) {
  USBMIDI.write(0xB0 | (channel & 0xf));
  USBMIDI.write(control & 0x7f);
  USBMIDI.write(value & 0x7f);
}

void sendNoteDown(uint8_t channel, uint8_t note, uint8_t velocity) {
  USBMIDI.write( 0x90  | (channel & 0xf));
  USBMIDI.write(note & 0x7f);
  USBMIDI.write(velocity &0x7f);
}

const int BUTTON_PIN_COUNT = 2;

// Change the order of the pins to change the ctrl or note order.
int buttonPins[BUTTON_PIN_COUNT] = { 2, 3 };

int buttonDown[BUTTON_PIN_COUNT];



int isButtonDown(int pin) {
  return digitalRead(pin) == 0;
}

void setup() {
 
  for (int i=0; i<BUTTON_PIN_COUNT; ++i) {
    pinMode(buttonPins[i], INPUT);
    digitalWrite(buttonPins[i], HIGH);
    buttonDown[i] = isButtonDown(buttonPins[i]);
  }
}

void loop() {
  //Handle USB communication
  USBMIDI.poll();

  while (USBMIDI.available()) {
    // We must read entire available data, so in case we receive incoming
    // MIDI data, the host wouldn't get stuck.
    u8 b = USBMIDI.read();
  }

  
  for (int i=0; i<BUTTON_PIN_COUNT; ++i) {
    int down = isButtonDown(buttonPins[i]);

    if (down != buttonDown[i]) {
      sendNoteDown(0, 64 + i, down ? 127 : 0);
      buttonDown[i] = down;
    }
  }

  // Flush the output.
  USBMIDI.flush();
}
