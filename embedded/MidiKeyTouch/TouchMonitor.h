/*
  Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA.

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

#if defined(USB_MIDI_SERIAL) || defined(USB_MIDI_AUDIO_SERIAL)
#define MONITOR
#endif

#ifdef MONITOR
static long start;

static void print_summary() {
  Serial.printf("clock %ld count %ld usecs/read %ld", TouchPads::clock(), (micros()-start)/TouchPads::clock());
  Serial.print(" |");
  for (int i = 0; i < NPADS; i += 1) Serial.printf(" %d:%d",i,TouchPads::touch(i));
  Serial.println(" |");
}
static void print_pin_names() {
  // pin name verification
  for (int i = 0; i < Teensy3Touch::npins; i += 1) {
    if (Teensy3Touch::pinChannel(i) == 255) continue;
    Serial.printf("%d: channel %d, pin %d\n", i, Teensy3Touch::pinChannel(i), Teensy3Touch::channelPin(Teensy3Touch::pinChannel(i)));
  }
}
static void print_raw_values() {
  Serial.print("r=|");
  for (int i = 0; i < NPADS; i += 1) Serial.printf("%d|", TouchPads::touch(i));
  Serial.println();
}
static void print_excess_values() {
  Serial.print("x=|");
  for (int i = 0; i < NPADS; i += 1) Serial.printf("%d|", TouchPads::excessTouch(i));
  Serial.println();
}
static void print_normalized_values() {
  // normalized values
  Serial.print("n=|");
  for (int i = 0; i < NPADS; i += 1) Serial.printf("%02x|", TouchPads::normTouch(i));
  Serial.println();
}
static void print_values() {
  Serial.print("v=|");
  for (int i = 0; i < NPADS; i += 1) Serial.printf("%d|", TouchPads::value(i));
  Serial.println();
}
static void print_pin(int c) {
  uint8_t i = c - '0';
  if (i >= 10) i = i + '0' - 'a' + 10;
  if (i >= NPADS) return;
  Serial.printf("%d pin %d channel %d min %d max %d rng %d val %d nrm %02x on %d\n", i, TouchPads::pin(i), TouchPads::channel(i),
		TouchPads::minTouch(i), TouchPads::maxTouch(i), TouchPads::rangeTouch(i), TouchPads::excessTouch(i),
		TouchPads::normTouch(i), TouchPads::value(i));
}
static void print_id() { Serial.printf("%s - %s - %s\n", _file, _date, _time); }
static void print_params() {
  Serial.printf("HARDWARE_AVERAGING %d, EXPONENTIAL_AVERAGING %d, TOUCH_THRESHOLD %x, FLASH_LED %d\n", 
		HARDWARE_AVERAGING, EXPONENTIAL_AVERAGING, TOUCH_THRESHOLD, FLASH_LED);
}
static void print_help() {
  for (int i = 0; i < NPADS; i += 1) Serial.printf("%x", i);
  Serial.printf(" - summarize values for pad numbers\n");
  Serial.printf("r - print raw values for pads\n");
  Serial.printf("x - print excess values for pads\n");
  Serial.printf("n - print normalized values for pads\n");
  Serial.printf("v - print on/off values for pads\n");
  Serial.printf("I - print identity\n");
  Serial.printf("N - print pin names\n");
  Serial.printf("P - print parameters\n");
  Serial.printf("R - reset touch pad ranges\n");
  Serial.printf("S - print summary\n");
  Serial.printf("? - print this help\n");
}
#endif
static void monitor() {
#ifdef MONITOR
  if (start == 0) start = micros();
  if (Serial.available()) {
    int c = Serial.read();
    switch (c) {
    case '0': case '1': case '2': case '3': case '4': // fall through
    case '5': case '6': case '7': case '8': case '9': // fall through
    case 'a': case 'b': case 'c': case 'd': case 'e': // fall through
    case 'f': print_pin(c); break;
    case 'r': print_raw_values(); break;
    case 'x': print_excess_values(); break;
    case 'n': print_normalized_values(); break;
    case 'v': print_values(); break;
    case 'I': print_id(); break;
    case 'N': print_pin_names(); break;
    case 'R': TouchPads::reset(); start = micros(); break;
    case 'P': print_params(); break;
    case 'S': print_summary(); break;
    case '?': print_help(); break;
    }
  }
#endif
}
