/*
** Scan touch inputs and maintain touch state.
** Set up a set of inputs to scan.
** Scanning proceeds continuously in the background.
** Optional callback from background to provide values at end of each scan.
** Or poll the clock() to determine end of scan.
*/
#ifndef Teensy3Touch_h
#define Teensy3Touch_h

#include "WProgram.h"

class Teensy3Touch
{
 private:
  /* no instance */
  Teensy3Touch() {}
  // These settings give approx 0.02 pF sensitivity and 1200 pF range
  // Lower current, higher number of scans, and higher prescaler
  // increase sensitivity, but the trade-off is longer measurement
  // time and decreased range.  We do NSCAN = 0, meaning 1 scan.
  // higher layers should do averaging to smooth the signal.
  static const int CURRENT = 2;	// 0 to 15 - current to use, value is 2*(current+1)
  static const int NSCAN = 9; // number of times to scan, 0 to 31, value is nscan+1
  static const int PRESCALE = 2; // prescaler, 0 to 7 - value is 2^(prescaler+1)

  // output is approx pF * 50
  // time to measure 33 pF is approx 0.25 ms
  // time to measure 1000 pF is approx 4.5 ms

  /* data */
  static uint32_t _clock;		/* interrupt counter */
  static uint16_t _value[16];		/* channel value */
  static uint16_t _error;		/* electrode/overflow/outofrange error status */
  static uint32_t _scanc;		/* precomputed _scanc register */
  static uint32_t _gencs;		/* precomputed _gencs register */
  static uint8_t _active[16];		/* active channel numbers */
  static uint8_t _nactive;		/* number of active channels programmed */
  static uint8_t _pactive;		/* currently active element of _active */
  static uint8_t _cactive;		/* currently scanning electrode channel */
  static uint8_t _scanning;		/* scanning is in progress */
  static void (*_callback)(uint16_t *);	/* callback at end of scan */

#if defined(__MK20DX128__) || defined(__MK20DX256__)
  // Teensy 3.0, 3.1, and 3.2
  static const uint8_t _pin2tsi[34];
#elif defined(__MK66FX1M0__)
  // Teensy 3.6
  static const uint8_t _pin2tsi[40];
#elif defined(__MKL26Z64__)
  // Teensy LC
  static const uint8_t _pin2tsi[27];
#endif

 public:
  /* The number of potential channels, only 11-12 actually exist on any Teensy3 so far */ 
  static const int nchannels = 16;
  /* The number of pins on this package */
  static const int npins = sizeof(_pin2tsi);
  /* check a channel mask for validity */
  static bool validChannels(uint16_t channels) {
    for (int i = 0; i < nchannels; i += 1)
      if ((channels & (1<<i)) && (channelPin(i) == 255))
	return 0;
    return 1;
  }
 public:
  /* retrieve and clear error */
  static uint16_t error() {
    uint16_t e = _error;
    _error = 0;
    return e;
  }
  /* translate teensy pin number to touch channel, 255 if not channel */
  static uint8_t pinChannel(uint8_t pin) {
    if (pin >= sizeof(_pin2tsi)) return 255;
    return _pin2tsi[pin];
  }
  /* translate TSI channel number to teensy pin number */
  static uint8_t channelPin(uint8_t channel) {
    for (unsigned pin = 0; pin < sizeof(_pin2tsi); pin += 1) if (_pin2tsi[pin] == channel) return pin;
    return 255;
  }
  /* last value seen on channel */
  static uint16_t value(uint8_t channel) { return _value[channel]; }
  /* test if scanning */
  static bool scanning() { return _scanning; }
  /* get the clock */
  static uint32_t clock() { return _clock; }
  /* start scanning */
  static uint16_t start(uint16_t mask,
			uint8_t refchrg = 3, uint8_t extchrg = 2, uint8_t nscan = 9, uint8_t prescale = 2, 
			void (*callback)(uint16_t *) = NULL) {
    if (_scanning) stop();
    /*
     * the bits set in the "mask" word specify the channels 
     * which should be actively scanned.
     * You can use pinChannel to find the channel corresponding to a pin.
     */
    _nactive = 0;
    if (mask == 0)
      return 0;
    for (int i = 0; i < nchannels; i += 1) {
      if ( ! (mask & (1<<i)) ) { // not in the scan
	continue;
      }
      if (channelPin(i) == 255) { // not connected on this processor
	_nactive = 0;
	return 0;
      }
      uint8_t pin = channelPin(i);
      *portConfigRegister(pin) = PORT_PCR_MUX(0);
      _active[_nactive++] = i;
      _value[i] = 0;
    }
    /* save callback */
    _callback = callback;
    /* gate clock to TSI */
    SIM_SCGC5 |= SIM_SCGC5_TSI;
    /* enable interrupt */
    NVIC_ENABLE_IRQ(IRQ_TSI);
    /* disable TSI */
    TSI0_GENCS = 0;
    /* start the scan */
    _pactive = 0;
    _cactive = _active[_pactive];
#if defined(HAS_KINETIS_TSI)
    /* set selected channel mask, trigger scan */
    TSI0_PEN = mask;
    /* reference and external oscillator current */
    TSI0_SCANC = TSI_SCANC_REFCHRG(refchrg) | TSI_SCANC_EXTCHRG(extchrg);
    /* number of scans, prescale, periodic trigger, enable TSI, trigger scan */
    TSI0_GENCS = TSI_GENCS_NSCN(nscan) | TSI_GENCS_PS(prescale) | TSI_GENCS_TSIIE | TSI_GENCS_ESOR | TSI_GENCS_TSIEN;
#elif defined(HAS_KINETIS_TSI_LITE)
    /* set the selected channel */
    TSI0_DATA = TSI_DATA_TSICH(_cactive);
    /* charges, prescale, nscan, end of scan interrupte */
    TSI0_GENCS = TSI_GENCS_REFCHRG(refchrg) | TSI_GENCS_EXTCHRG(extchrg) | TSI_GENCS_PS(prescale) | TSI_GENCS_NSCN(nscan) |
      TSI_GENCS_TSIIEN | TSI_GENCS_ESOR | TSI_GENCS_TSIEN;
#endif
    /* software trigger scan */
#if defined(HAS_KINETIS_TSI)
    TSI0_GENCS |=  TSI_GENCS_SWTS;
#elif defined(HAS_KINETIS_TSI_LITE)
    TSI0_DATA |= TSI_DATA_SWTS;
#endif
    /* tag as scanning */
    _scanning = 1;
    return mask;
  }

  /* stop scanning */
  static void stop() {
    if ( ! _scanning) return;
    /* clear the scanning flag */
    _scanning = 0;
    /* disable TSI */
    TSI0_GENCS = 0;
    /* disable interrupt */
    NVIC_DISABLE_IRQ(IRQ_TSI);
    /* clear callback */
    _callback = NULL;
  }
  
  /* Process end of scan interrupt */
  static void touchISR() {
#if defined(HAS_KINETIS_TSI)
    // count end of scan
    _clock += 1;
    // fetch counts
    for (int i = 0; i < _nactive; i += 1) {
      int j = _active[i];
      _value[j] = *((volatile uint16_t *)(&TSI0_CNTR1) + j);
    }
    if (_callback != NULL) _callback(_value);
    // clear eosf and trigger scan
    TSI0_GENCS |= TSI_GENCS_EOSF | TSI_GENCS_SWTS;
#elif  defined(HAS_KINETIS_TSI_LITE)
    // fetch counts and combine with running average
    _value[_cactive] = (TSI0_DATA & 0xFFFF);
    // advance to next electrode
    if (++_pactive >= _nactive) {
      // count end of scan
      _clock += 1;
      if (_callback != NULL) _callback(_value);
      // restart scan
      _pactive = 0;
    }
    // get next electrode number
    _cactive = _active[_pactive];
    // reset the end-of-scan flag
    TSI0_GENCS |= TSI_GENCS_EOSF;
    // reprogram for next scan, and trigger
    TSI0_DATA = TSI_DATA_TSICH(_cactive) | TSI_DATA_SWTS;
#endif
  }
};
#endif // TeensyTouch_h
