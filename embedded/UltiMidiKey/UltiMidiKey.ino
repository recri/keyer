/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.

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

/* UltiMidiKey -
   Iambic paddles to USB MIDI
   MIDI to key and sidetone out
   Touch Paddle / Key
   Built in keyer with touch button control
   
   You must select Serial + MIDI from the "Tools > USB Type" menu,

   This is a very trimmed and modified copy of the Buttons
   example from the Teensyduino add on to the Arduino.  At
   least it was once upon a time.

   To use it, you need:

   1) to get a Teensy LC from http://www.pjrc.com/teensy/
   or some other supplier, eg http://www.adafruit.com/products/199
   2) to follow the instructions for installing Teensyduino at
   http://www.pjrc.com/teensy/teensyduino.html

*/

#include <WProgram.h>

#define USE_AUDIO_DAC 1
#define USE_VK6PH_KEYER 1

///
/// parameters
///
int tone_freq = 600;            // tone frequency
#ifdef USE_AUDIO_DAC
float tone_level = 1.0;         // tone level
int tone_rise = 2;              // ms of rise time for tone
int tone_fall = 2;              // ms of fall time for tone
#endif
float touch_sensitivity = 7;    // number of sd over mean that signals touch
int transition_timeout = 1;     // debounce refractory period after transition, ms
byte sidetone_follows_key = 1;  // generate sidetone when key is active

///
/// terminate with endless complaint
///
static int abort(char *msg) {
  while(1) { 
    Serial.println(msg);
    delay(15);
  }
  /* never returns */
}

///
/// Midi note codes used for key input events and key outputs
///
#define MIDI_NIL       0xff
#define MIDI_KEYIN_DAH 0  /* the right paddle, stereo tip / trrs tip, straight key key */
#define MIDI_KEYIN_DIT 1  /* the left paddle, stereo ring / trrs ring1 */
#define MIDI_KEYIN_PTT 3  /* the other button, trrs ring2 */
#define MIDI_KEYIN_B1  4  /* the other touch buttons on the key */
#define MIDI_KEYIN_B2  5
#define MIDI_KEYIN_B3  6
#define MIDI_KEYIN_B4  7
#define MIDI_KEYIN_B5  8
#define MIDI_KEYIN_B6  9
#define MIDI_KEYIN_B7  10

#define MIDI_KYOUT_KEY 0   /* key out from MIDI controller */
#define MIDI_KYOUT_PTT 1   /* ptt out from MIDI controller */
#define MIDI_KYOUT_ST  2   /* sidetone from MIDI controller */
#define MIDI_KYOUT_LED 3   /* led light from MIDI controller */
#define MIDI_KYOUT_PW1 4   /* unfiltered PWM according to velocity */
#define MIDI_KYOUT_PW2 5   /* unfiltered PWM according to velocity */

///
/// pin table, one entry for each pin
///
enum pin_type { key_switch, key_touch, out_ground, out_active_high, out_active_low, out_dac, out_tone, out_pwm };
enum connect_type { tip, ring1, ring2, shield, other };
struct pin {
  enum pin_type type;
  enum connect_type ctype;
  byte channel;      // MIDI channel
  byte note;         // MIDI note
  byte pin;          // Arduino pin
  byte next;         // index to next in input/output chain
  byte key;          // the most recent value of this input key
  byte active;       // is this output sounding?
  uint32_t transition_time;     // timeout for refractory period
} pin[] = {
  /* touch paddle */
  { key_touch,       other, 1, MIDI_KEYIN_DIT,17 }, // dress through G and PROGRAM on edge
  { key_touch,       other, 1, MIDI_KEYIN_DAH,23 }, // dress through 3V on edge

  /* touch buttons */
  { key_touch,       other, 1, MIDI_KEYIN_B1,  0 }, // dress between VIN and G
  { key_touch,       other, 1, MIDI_KEYIN_B2,  1 }, // dress between 3.3V and 23
  { key_touch,       other, 1, MIDI_KEYIN_B3, 22 }, // dress between 22 and 21
  { key_touch,       other, 1, MIDI_KEYIN_B4, 19 }, // dress between 20 and 19
  { key_touch,       other, 1, MIDI_KEYIN_B4, 18 }, // dress between 18 and 17
  { key_touch,       other, 1, MIDI_KEYIN_B6, 16 }, // dress between 16 and 15
  { key_touch,       other, 1, MIDI_KEYIN_B7, 15 }, // dress between 14 and 13

  /* input/output/pwm/tone block */
  { out_ground,      shield,0, MIDI_NIL,       2 },
  /* alternative key input */
  { key_switch,      tip,   1, MIDI_KEYIN_DIT, 3 },
  { key_switch,      ring1, 1, MIDI_KEYIN_DAH, 4 },
  /* alternative key output
  { out_active_low,  tip,   1, MIDI_KYOUT_KEY, 3 },
  { out_active_low,  ring1, 1, MIDI_KYOUT_PTT, 4 }, */
  /* alternative pwm output
  { out_pwm,         tip,   1, MIDI_KYOUT_PW1, 3 },
  { out_pwm,         ring1, 1, MIDI_KYOUT_PW2, 4 }, */
  /* alternative tone output
  { out_tone,        tip,   1, MIDI_KYOUT_ST, 3 },
  { out_ground,      ring1, 1, MIDI_NIL,      4 }, */

  /* input/output block */
  { out_ground,      shield,9, MIDI_NIL,       5 },
  /* alternative key input 
  { key_switch,      tip,   1, MIDI_KEYIN_DIT, 6 },
  { key_switch,      ring1, 1, MIDI_KEYIN_DAH, 7 }, */
  /* alternative key output */
  { out_active_low,  tip,   1, MIDI_KYOUT_KEY, 6 },
  { out_active_low,  ring1, 1, MIDI_KYOUT_PTT, 7 },
  /* alternative not used
  { out_ground,      tip,   1, MIDI_NIL,       6 },
  { out_ground,      ring1, 1, MIDI_NIL,       7 }, */

  /* input/output/pwm/tone block */
  { out_ground,      shield,0, MIDI_NIL,       8 }, 
  /* alternative key output 
  { out_active_low,  tip,   1, MIDI_KYOUT_KEY, 9 },
  { out_active_low,  ring1, 1, MIDI_KYOUT_PTT,10 }, */
  /* alternative key input
  { key_switch,      tip,   1, MIDI_KEYIN_DAH, 9 },
  { key_switch,      ring1, 1, MIDI_KEYIN_DIT,10 }, */
  /* alternative pwm output
  { out_pwm,         tip,   1, MIDI_KYOUT_PW1, 9 },
  { out_pwm,         ring1, 1, MIDI_KYOUT_PW2,10 }, */
  /* alternative tone output */
  { out_tone,        tip,   1, MIDI_KYOUT_ST, 9 },
  { out_ground,      ring1, 1, MIDI_NIL,     10 },
  /* alternative not used 
  { out_ground,      tip,   1, MIDI_NIL,      9 }, 
  { out_ground,      ring1, 1, MIDI_NIL,     10 }, */

  /* connection for built in LED */
  { out_active_high, other, 1, MIDI_KYOUT_LED,13 },        
  
  /* connection for DAC audio */
  { out_ground,      shield,0, MIDI_NIL,      14 }, 
  { out_dac,         tip,   1, MIDI_KYOUT_ST, 26 },

  { out_ground,      shield,0, MIDI_NIL,      20 }, 
  /* alternative connections for key out
  { out_active_low,  tip,   1, MIDI_KYOUT_KEY,21 },
  { out_active_low,  ring1, 1, MIDI_KYOUT_PTT,24 }, */
  /* alternative for  key input
  { key_switch,      tip,   1, MIDI_KEYIN_DAH,21 },
  { key_switch,      ring1, 1, MIDI_KEYIN_DIT,24 }, */
  /* alternative not used */
  { out_ground,      other, 1, MIDI_NIL,      21 },
  { out_ground,      other, 1, MIDI_NIL,      24 },

  /* alternative block, awkward wiring */
  { out_ground,      shield,0, MIDI_NIL,      11 }, 
  { out_ground,      other, 1, MIDI_NIL,      12 },
  { out_ground,      shield,0, MIDI_NIL,      25 }, 
};
#define n_pins (sizeof(pin)/sizeof(pin[0]))

///
/// touch pin table
///
struct touch_pin {
  int touch_level;              // last read raw touch level
  int new_touch_level;          // newly read raw touch level
  float threshold;              // cum_avg+touch_sensitivity*cum_sd
  float cum_avg;
  float cum_var;
  int cum_n;
  float cum_sd;
  float raw_avg;
  float raw_var;
  int raw_n;
} touch_pin[9];
#define n_touch_pins 9

byte first_input;
byte first_output;

static inline void pinsetup(void) {
  first_input = 0xFF;
  first_output = 0xFF;;
  int used = 0;
  for (int i = n_pins; --i >= 0; ) {
    struct pin *p = &pin[i];
    if (used & (1<<p->pin)) abort("pinsetup used conflict");
    used |= (1<<p->pin);
    switch (pin[i].type) {
    case out_ground:
      /* ground handled here and done */
      pinMode(p->pin, OUTPUT);
      digitalWrite(p->pin, LOW);
      break;
    case key_touch: 
      /* test that touch keys come sequentially first */
      if (i >= n_touch_pins) abort("pinsetup touch out of line");
      /* fall through */
    case key_switch:
      /* inputs linked together */
      p->next = first_input;
      first_input = i;
      break;
    case out_active_high:
    case out_active_low:
    case out_dac:
    case out_tone:
    case out_pwm:
      /* outputs linked together */
      p->next = first_output;
      first_output = i;
      break;
    default:
      abort("pinsetup uncaught case");
    }      
  }
}


///
/// switched key handling
///
static int switch_read(struct pin *kp) {
  return digitalRead(kp->pin);
}

///
/// touch key handling
///
#include "touch.h"

enum { idle, started, ready } touchScanState = idle;
elapsedMicros touchScanTime;
elapsedMicros touchReadyTime;
byte touchKeyIndex = 0xff;
byte touchKeySequence[] = { 
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
};

static inline struct pin* touch_key_get(int i) {
  if (i >= 0 && i < n_pins && pin[i].type == key_touch) return pin+i;
  abort("touch_key_get");
}

static inline void touch_service() {
  struct pin *p;
  struct touch_pin *tp;
  switch (touchScanState) {
  case idle:
    if (touchKeySequence[0] == 0xff)        // nothing set up
      return;                               // just bail
    touchKeyIndex = 0;                      // initalize index
    p = touch_key_get(touchKeySequence[touchKeyIndex]);
    tp = &touch_pin[p-pin];
    touchScan(p->pin);                        // start scan on pin
    touchScanTime = 0;                      // start scan counter
    touchScanState = started;               // set scan started state
    return;
  case started:
    if (touchScanTime <= 10) return;        // too soon after start of scan
    p = touch_key_get(touchKeySequence[touchKeyIndex]);
    tp = &touch_pin[p-pin];
    if (! touchReady(p->pin)) return;          // scan not complete
    touchReadyTime = 0;                     // start ready counter
    touchScanState = ready;                 // set ready state
    return;
  case ready:
    if (touchReadyTime <= 1) return;        //  not ready
    p = touch_key_get(touchKeySequence[touchKeyIndex]);
    tp = &touch_pin[p-pin];
    tp->new_touch_level = touchValue(p->pin); // get new value
    touchKeyIndex += 1;
    // start next key scan
    if (touchKeySequence[touchKeyIndex] == 0xff)
      touchKeyIndex = 0;
    p = touch_key_get(touchKeySequence[touchKeyIndex]);
    tp = &touch_pin[p-pin];
    touchScan(p->pin);                        // start scan on pin
    touchScanTime = 0;                      // start scan counter
    touchScanState = started;               // set scan started state
    return;
  default:
    abort("touch_service");
  }
}

static inline void touch_sequence_add(byte tkey) {
  for (int i = 0; i < sizeof(touchKeySequence)-1; i += 1)
    if (touchKeySequence[i] == 0xff) {
      touchKeySequence[i] = tkey;
      return;
    }
  abort("touch_sequence_add");
}

/*
 * compute running mean and var from https://www.johndcook.com/blog/standard_deviation
 *
 * Initialize M1 = x1 and S1 = 0.
 *
 * For subsequent x‘s, use the recurrence formulas
 * 
 * Mk = Mk-1+ (xk – Mk-1)/k
 * Sk = Sk-1 + (xk – Mk-1)*(xk – Mk).
 *
 * For 2 ≤ k ≤ n, the kth estimate of the variance is s2 = Sk/(k – 1).
 */

static int touch_read(struct pin *kp) {
  kp->type != key_touch && abort("touch_read called from wrong type key");
  touch_service();
  struct touch_pin *tp = &touch_pin[kp-pin];
  if (tp->new_touch_level != 0) {
    int v = tp->new_touch_level;
    tp->new_touch_level = 0;
    if (tp->raw_n == 0) {
      tp->raw_n = 1;
      tp->raw_avg = v;
      tp->raw_var = 0;
    } else {
      float old_avg = tp->raw_avg;
      tp->raw_n += 1;
      tp->raw_avg += (v-old_avg)/tp->raw_n;
      tp->raw_var += (v-old_avg)*(v-tp->raw_avg);
      if (tp->raw_n == 1024) {
        if (tp->cum_n == 0 || tp->raw_var < tp->cum_var) {
          tp->cum_n = tp->raw_n;
          tp->cum_avg = tp->raw_avg;
          tp->cum_sd = sqrtf(tp->raw_var/(tp->raw_n-1));
          tp->threshold = tp->cum_avg+touch_sensitivity*tp->cum_sd;
        }
        tp->raw_n = 0;
      } 
    }
    tp->touch_level = v;
  }
  return tp->cum_n == 0 ? 1 : tp->touch_level < tp->threshold;
}

static void touch_stats_reset(void) {
  for (byte i = first_input; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    struct touch_pin *tp = &touch_pin[i];
    if (p->type == key_touch) {
      tp->raw_avg = 0;
      tp->raw_var = 0;
      tp->raw_n = 0;
    }
  }
}

static void touch_key_stats(struct touch_pin *tp) {
  Serial.print(" raw mean "); Serial.print(tp->raw_avg);
  if (tp->raw_n >= 2) {
    Serial.print(" sd "); Serial.print(sqrtf(tp->raw_var/(tp->raw_n-1)));
  }
  Serial.print(" n "); Serial.print(tp->raw_n);
  Serial.print(" cum mean "); Serial.print(tp->cum_avg);
  Serial.print(" sd "); Serial.print(tp->cum_sd);
  Serial.print(" n "); Serial.print(tp->cum_n);
  Serial.println();
}

static void touch_stats(void) {
  for (byte i = first_input; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    if (p->type == key_touch) {
      Serial.print("pin[ ");
      Serial.print(p->pin);
      Serial.print("]: ");
      touch_key_stats(&touch_pin[i]);
    }
  }
}


///
/// key handling
///
static inline void keysetup() {
  for (byte i = first_input; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    if (p->type == key_switch) {
      pinMode(p->pin, INPUT_PULLUP);
      p->key = switch_read(p);
    } else if (p->type == key_touch) {
      p->key = touch_read(p);
      touch_sequence_add(p-pin);
    } else {
      abort("Unknown key type found.");
    }
  }
  // initialize touch stats
  touch_stats_reset();
  // test for key stuck on
  // for (unsigned i = 0; i < n_pins; i += 1) {
  //    if (pin[i].key == 0) {
  //    }
  //  }
  /* test for stuck keys and for startup with keys held on */
  /* the ring2 switches will be grounded if a TRS plug is used */
  /* the ring1 and ring2 switches will be grounded if a TS plug is used */
}

static inline void keyloop() {
  uint32_t current_time = micros();
  for (byte i = first_input; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    int new_key;
    switch (p->type) {
    case key_switch:
      new_key = switch_read(p);
      break;
    case key_touch: 
      new_key = touch_read(p);
      break;
    default:
      abort("keyloop");
    }
    if (new_key != p->key && 
        (p->transition_time == 0 ||
         current_time-p->transition_time >= transition_timeout)) {
      p->transition_time = current_time;
      midi_send_note(p->note);
      usbMIDI.sendNoteOn(p->note, new_key != 0 ? 0 : 1, p->channel);
      usbMIDI.send_now();
      p->key = new_key;
    }
    continue;
  }
}


///
/// midi stats
///
static unsigned int midi_in[11] = { 0 };
static unsigned int midi_out[6] = { 0 };

static inline void midi_send_note(byte note) {
  if (note >= 0 && note < 11) midi_in[note] += 1;
}
static inline void midi_recv_note(byte note) {
  if (note >= 0 && note < 6) midi_out[note] += 1;
}
static inline void midi_stats(void) {
  for (byte i = 0; i < 11; i += 1)
    if (midi_in[i]) {
      Serial.print("i["); Serial.print(i); Serial.print("] = "); Serial.println(midi_in[i]);
      midi_in[i] = 0;
    }
  for (byte i = 0; i < 6; i += 1)
    if (midi_out[i]) {
      Serial.print("o["); Serial.print(i); Serial.print("] = "); Serial.println(midi_out[i]);
      midi_out[i] = 0;
    }
}

///
/// output handling
///
#ifdef USE_AUDIO_DAC
#include <Audio.h>
// Audio setup for dac
// GUItool: begin automatically generated code
AudioSynthWaveformSine   sine1;          //xy=504,513
AudioEffectFade          fade1;          //xy=737,516
AudioOutputAnalog        dac1;           //xy=987,516
AudioConnection          patchCord1(sine1, fade1);
AudioConnection          patchCord2(fade1, dac1);
// GUItool: end automatically generated code
#endif

static void my_note_on(byte channel, byte note, byte velocity) {
  if (velocity == 0)
    my_note_off(channel, note, velocity);
  else
    for (byte i = first_output; i != 0xFF; i = pin[i].next) {
      struct pin *p = &pin[i];
      if (p->channel == channel && p->note == note) {
        midi_recv_note(p->note);
        switch (p->type) {
        case out_active_high:
          digitalWrite(p->pin, HIGH);
          break;
        case out_active_low:
          digitalWrite(p->pin, LOW);
          break;
        case out_dac:
#ifdef USE_AUDIO_DAC
          sine1.amplitude(tone_level);
          sine1.frequency(tone_freq);
          fade1.fadeIn(tone_rise);
#endif
          break;
        case out_tone:
          tone(p->pin, tone_freq);
          break;
        case out_pwm:
          analogWrite(p->pin, velocity);
          break;
        default:
          abort("my_note_on");
        }
        if (note == MIDI_KYOUT_KEY && sidetone_follows_key)
          my_note_on(channel, MIDI_KYOUT_ST, velocity);
      }
    }
}

static void my_note_off(byte channel, byte note, byte velocity) {
  for (byte i = first_output; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    if (p->channel == channel && p->note == note) {
      midi_recv_note(p->note);
      switch (p->type) {
      case out_active_high:
        digitalWrite(p->pin, LOW);
        break;
      case out_active_low:
        digitalWrite(p->pin, HIGH);
        break;
      case out_dac:
#ifdef USE_AUDIO_DAC
        fade1.fadeOut(tone_fall);
        /* sine1.amplitude(tone_level); oh, turn off when fade completes. */
        /* sine1.frequency(tone_freq); oh, turn off when fade completes. */
#endif
        break;
      case out_tone:
        noTone(p->pin);
        break;
      case out_pwm:
        analogWrite(p->pin, 0);
        break;
      }
      if (p->note == MIDI_KYOUT_KEY && sidetone_follows_key)
        my_note_off(channel, MIDI_KYOUT_ST, velocity);
    }
  }
}

static inline void outsetup() {
  for (byte i = first_output; i != 0xFF; i = pin[i].next) {
    struct pin *p = &pin[i];
    switch (p->type) {
    case out_active_high:
      pinMode(p->pin, OUTPUT);
      digitalWrite(p->pin, LOW);
      break;
    case out_active_low:
      pinMode(p->pin, OUTPUT);
      digitalWrite(p->pin, HIGH);
      break;
    case out_dac:
    case out_tone:
    case out_pwm:
      break;
    default:
      abort("outsetup");
    }
  }
  // Initialize incoming MIDI handlers
  usbMIDI.setHandleNoteOff(my_note_off);
  usbMIDI.setHandleNoteOn(my_note_on);
}

static inline void outloop() {
  while (usbMIDI.read());
}

///
/// iambic keyer
///
#include "iambic_vk6ph.h"
iambic_vk6ph keyer;

//
// serial line command interpreter
//
static inline void serialloop() {
  switch (Serial.read()) {
  case '0': touch_stats_reset(); break;
  case '+':
    my_note_on(1, MIDI_KYOUT_ST, 127);
    break;
  case '-':
    my_note_off(1, MIDI_KYOUT_ST, 0);
    break;
  case '?': 
#ifdef USE_AUDIO_DAC
    Serial.print("max audio "); Serial.println(AudioMemoryUsageMax());
#endif
    midi_stats();
    touch_stats();
    break;
  case '\n': break;
  default: break;
  }
}

static inline void serialsetup() {
  Serial.begin(9600);
}

///
/// optional timing the loop execution
///
//#define TIMING 1      // uncomment to enable
#ifdef TIMING
float average_micros_per_loop;
elapsedMicros micros_for_loop;
long loop_counter;

static inline void timingsetup() {
  average_micros_per_loop = 0;
  micros_for_loop = 0;
  loop_counter = 0;
}
static inline void timingloop() {
  if (++loop_counter >= 16*1024) {
    long now_micros = micros_for_loop;
    average_micros_per_loop += (float)now_micros / loop_counter;
    average_micros_per_loop /= 2;
    micros_for_loop = 0;
    loop_counter = 0;
    Serial.println(average_micros_per_loop);
  }
}
#else
// nil timing loop
static inline void timingsetup() {}
static inline void timingloop() {}
#endif
  
///
/// main entry points
///
void setup() {
#ifdef USE_AUDIO_DAC
  AudioMemory(2);
#endif
  pinsetup();                   // form the linked lists, implement grounds, check for dups
  keysetup();                   // setup the key pins
  outsetup();                   // setup the output pins
  serialsetup();
  timingsetup();                // set up the loop timing
}

void loop() {
  keyloop();                 // read and process input switches
  outloop();                 // read and process incoming MIDI messages.
  serialloop();              // serial read
  timingloop();              // time the loop
}
