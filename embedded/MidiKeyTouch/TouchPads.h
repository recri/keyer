/* -*-C++-*- */
#ifndef touch_pads_h
#define touch_pads_h

#include "Teensy3Touch.h"

// this might be improved if it made an instance
// with npads and pins as constructor parameters
// and let everything be instance variables of
// the correct size.
// tried it without looking up the syntax for
// initializing constants in the constructor
// and it didn't work, should try again.

#ifndef NPADS
#error "NPADS and PADS should be defined before TouchPads.h is included"
#endif

class TouchPads {
protected:
  static uint8_t _npads;
  static uint8_t _pads[NPADS];		// the pin number for each pad
  static uint8_t _channels[NPADS];	// the touch hardware channel number

  static uint16_t _touch[NPADS];	// the raw touch reading
  static uint8_t _electrodes[NPADS];	// electrone error flag
  static uint16_t _minTouch[NPADS];	// the minimum over the averaged touch
  static uint16_t _maxTouch[NPADS];	// the maximum over the averaged touch
  static uint8_t _normTouch[NPADS];	// the normalized touch
  static uint8_t _threshold;		// the on/off threshold in normalized touch
  static uint16_t _last_touch;		// (_normTouch[i]>_threshold?1:0)<<i
  static uint8_t _expo;			// log2(exponential average denominator) 

  static uint8_t _callbackFlag;
  static uint32_t _callbackCount;

  TouchPads() {}		// no instance
public:
  static void begin(uint8_t npads, uint8_t *pads) {
    // if (npads > NPADS) abort();
    _npads = npads;
    set_expo(EXPONENTIAL_AVERAGING);
    set_threshold(TOUCH_THRESHOLD);
    uint16_t maskpins = 0;
    for (int i = 0; i < _npads; i += 1) {
      _pads[i] = pads[i];
      _channels[i] = Teensy3Touch::pinChannel(_pads[i]);
      maskpins |= (1<<_channels[i]);
    }
    reset();
    Teensy3Touch::start(maskpins,3,2,HARDWARE_AVERAGING,2,_callback);// 1 scan
  }
  
  static void reset() {
    for (int i = 0; i < _npads; i += 1) {
      _touch[i] = 0;
      _maxTouch[i] = 0;
      _minTouch[i] = 65535;
    }
  }

  // compute exponential average
  // if (expo == 0) return val;					// 0 avg + 1 val
  // if (expo == 1) return (avg + val) / 2			// 1/2 avg + 1/2 val
  // if (expo == 2) return (avg + 2*avg + val) / 4;		// 3/4 avg + 1/4 val
  // if (expo == 3) return (avg + 2*avg + 4*avg + val) / 8;	// 7/8 avg + 1/8 val
  // if (expo == 4) return (avg + 2*avg + 4*avg + 8*avg + val) / 16;		// 15/16 avg + 1/16 val
  // if (expo == 5) return (avg + 2*avg + 4*avg + 8*avg + 16*avg + val) / 32;	// 31/32 avg + 1/32 val
  // etc.
  static uint16_t exponential_average(uint16_t avg, uint16_t val, uint8_t expo) {
    uint32_t acc = avg;
    switch (expo) {
    case 8: acc <<= 1; acc += avg; // fall through
    case 7: acc <<= 1; acc += avg; // fall through
    case 6: acc <<= 1; acc += avg; // fall through
    case 5: acc <<= 1; acc += avg; // fall through
    case 4: acc <<= 1; acc += avg; // fall through
    case 3: acc <<= 1; acc += avg; // fall through
    case 2: acc <<= 1; acc += avg; // fall through
    case 1: return (acc + val) >> expo;
    case 0: return val;
    default: return 0;
    }
  }

protected:
  static void _callback(uint16_t *value) {
    _callbackFlag += 1;
    _callbackCount += 1;
    if (_callbackCount == 256) reset();
    for (int i = 0; i < _npads; i += 1) {
      uint16_t val = value[_channels[i]];
      if (val == 0 || val == 65535) {
	_electrodes[i] |= 1; 
	val = _minTouch[i];
      }
      if (_touch[i] == 0) _touch[i] = val;
      _touch[i] = exponential_average(_touch[i], val, _expo);
      _maxTouch[i] = max(_maxTouch[i], _touch[i]);
      _minTouch[i] = min(_minTouch[i], _touch[i]);
      uint16_t range = _maxTouch[i]-_minTouch[i];
      uint16_t excess = _touch[i]-_minTouch[i];
      uint16_t scale = range < 5 ? 0 : range > 0xff ? 1 : 0xff / range;
      _normTouch[i] = scale * excess;
    }
  }

public:
  // set the off/on threshold for normalized touch values
  static void set_threshold(uint8_t threshold) { _threshold = threshold; }

  static void set_expo(uint8_t expo) { _expo = expo > 8 ? 0 : expo; }

  // see if a new touch configuration is available
  static bool available() {
    if ( ! _callbackFlag)
      return false;
    uint16_t new_touch = 0;
    for (int i = 0; i < _npads; i += 1) {
      new_touch |= (_normTouch[i] > _threshold ? 1 : 0)<<i;
    }
    if (new_touch != _last_touch) {
      _last_touch = new_touch;
      return true;
    }
    return false;
  }

  static uint32_t clock() { return _callbackCount; }
  static uint16_t last_touch() { return _last_touch; }
  static uint8_t pin(int i) { return _pads[i]; }
  static uint8_t channel(int i) { return _channels[i]; }
  static uint16_t touch(int i) { return _touch[i]; }
  static uint16_t minTouch(int i) { return _minTouch[i]; }
  static uint16_t maxTouch(int i) { return _maxTouch[i]; }
  static uint16_t rangeTouch(int i) { return _maxTouch[i]-_minTouch[i]; }
  static uint16_t excessTouch(int i) { return _touch[i]-_minTouch[i]; }
  static uint8_t normTouch(int i) { return _normTouch[i]; }
  static uint8_t value(int i) { return _normTouch[i] > _threshold; }
};

// allocate static data
uint8_t TouchPads::_npads;
uint8_t TouchPads::_pads[NPADS];
uint8_t TouchPads::_channels[NPADS];

uint16_t TouchPads::_touch[NPADS];
uint8_t TouchPads::_electrodes[NPADS];
uint16_t TouchPads::_minTouch[NPADS];
uint16_t TouchPads::_maxTouch[NPADS];
uint8_t TouchPads::_normTouch[NPADS];
uint8_t TouchPads::_threshold;
uint8_t TouchPads::_expo;
uint16_t TouchPads::_last_touch;
uint8_t TouchPads::_callbackFlag;
uint32_t TouchPads::_callbackCount;

#endif // touch_pads_h
