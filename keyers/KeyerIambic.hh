#ifndef KeyerIambic_hh
#define KeyerIambic_hh

/*
** A morse code keyer reduced to a simple logic class.
**
** // usage
** KeyerIambic k();	// to make a keyer
** k.paddleDit(on);	// to set the dit paddle state
** k.paddleDah(on);	// to set the dah paddle state
** k.clock(ticks);	// to advance the clock by ticks
** k.setKeyOut(func);	// function to receive transitions
**
** // parameter setting
** k.set*(param)
**
** // parameter query
** k.get*(param)
*/

/*
** May need to parameterize the ticks type
** in case the int is too small on an microprocessor
*/

class KeyerIambic {
private:
#define KEYIN(dit,dah) (((dit)<<1)|(dah))
  typedef unsigned char byte;
  //static int KEYIN(int dit, int dah) { return ((dit<<1)|dah); }
  static const int KEYIN_OFF = KEYIN(0,0);
  static const int KEYIN_DIT = KEYIN(1,0);
  static const int KEYIN_DAH = KEYIN(0,1);
  static const int KEYIN_DIDAH = KEYIN(1,1);
  static bool KEYIN_IS_DIT(int keyIn) { return (keyIn&KEYIN_DIT)!=0; }
  static bool KEYIN_IS_DAH(int keyIn) { return (keyIn&KEYIN_DAH)!=0; }
  
public:
  KeyerIambic() {
    _rawDit = 0;
    _rawDah = 0;
    _keyOut = false;

    _keyIn = KEYIN_OFF;
    _lastKeyIn = KEYIN_OFF;
    _prevKeyInPtr = 0;

    setKeyOut((void (*)(int))0);
    setTick(1);
    setSwapped(false);
    setModeB(false);
    setWord(50);
    setWpm(15);
    setDah(3);
    setIes(1);
    setIls(3);
    setIws(7);
    setAutoIls(false);
    setAutoIws(false);
    update();
  }

  // set the dit paddle state
  void paddleDit(bool on) {  _rawDit = on ? 1 : 0; }
  // set the dah paddle state
  void paddleDah(bool on) {  _rawDah = on ? 1 : 0; }
  // clock ticks
  void clock(int ticks) {
    // update timings if necessary
    if (_update) update();

    // fetch input state
    byte keyIn = _swapped ? KEYIN(_rawDah, _rawDit) : KEYIN(_rawDit, _rawDah);
    if (_keyIn != keyIn) _lastKeyIn = _keyIn;
    _keyIn = keyIn;

    // start a symbol if either paddle is pressed
    if (_keyerState == KEYER_OFF) {
      _startSymbol();
      _restartHalfClock(keyIn);
      return;
    }

    // reduce the half clock by the time elapsed
    // if the half clock duration elapsed, reset
    if ((_halfClockDuration -= ticks) <= 0) _restartHalfClock(keyIn);

    // reduce the duration by the time elapsed
    // if the duration has not elapsed, return
    if ((_keyerDuration -= ticks) > 0) return;

    // determine the next element by the current paddle state
    switch (_keyerState) {
    case KEYER_DIT: // finish the dit with an interelement space
      _startSpace(KEYER_DIT_SPACE); break;
    case KEYER_DAH: // finish the dah with an interelement space
      _startSpace(KEYER_DAH_SPACE); break;
    case KEYER_DIT_SPACE: // start the next element or finish the symbol
      _startDah() || _startDit() || _continueSpace(KEYER_SYMBOL_SPACE, _ticksPerIls-_ticksPerIes); break;
    case KEYER_DAH_SPACE: // start the next element or finish the symbol	
      _startDit() || _startDah() || _continueSpace(KEYER_SYMBOL_SPACE, _ticksPerIls-_ticksPerIes); break;
    case KEYER_SYMBOL_SPACE: // start a new symbol or finish the word
      _startSymbol() || _continueSpace(KEYER_WORD_SPACE, _ticksPerIws-_ticksPerIls); break;
    case KEYER_WORD_SPACE:  // start a new symbol or go to off
      _startSymbol() || _finish(); break;
    }
  }

  // set the function to be called for key transitions
  void setKeyOut(void (*keyOut)(int on)) { _keyOut = keyOut; }
  // set the microseconds in a tick
  void setTick(float tick) { _tick = tick; _update = true; }
  // set the words per minute generated
  void setWpm(float wpm) { _wpm = wpm; _update = true; }
  float getWpm() { return _wpm; }
  // word length in dits
  void setWord(float word) { _word = word; _update = true; }
  float getWord() { return _word; }
  // set the paddle key mode
  void setModeB(bool modeB) { _modeB = modeB; }
  bool getModeB() { return _modeB; }
  // swap the dit and dah paddles
  void setSwapped(bool swapped) { _swapped = swapped; }
  bool getSwapped() { return _swapped; } 
  // set the dah length in dits
  void setDah(float dahLen) { _dahLen = dahLen; _update = true; }
  float getDah() { return _dahLen; }
  // set the inter-element length in dits
  void setIes(float iesLen) { _iesLen = iesLen; _update = true; }
  float getIes() { return _iesLen; }
  // set the inter-letter length in dits
  void setIls(float ilsLen) { _ilsLen = ilsLen; _update = true; }
  float getIls() { return _ilsLen; }
  // set the inter-word length in dits
  void setIws(float iwsLen) { _iwsLen = iwsLen; _update = true; }
  float getIws() { return _iwsLen; }
  // set the auto inter-letter spacing
  void setAutoIls(bool autoIls) { _autoIls = autoIls; }
  bool getAutoIls() { return _autoIls; }
  // set the auto inter-word spacing
  void setAutoIws(bool autoIws) { _autoIws = autoIws; }
  bool getAutoIws() { return _autoIws; }
  
  // update the clock computations
  void update() {
    if (_update) {
      _update = false;
      // microsecond timing
      _microsPerDit = 60000000.0 / (_wpm * _word);
      _microsPerDah = _microsPerDit * _dahLen;
      _microsPerIes = _microsPerDit * _iesLen;
      _microsPerIls = _microsPerDit * _ilsLen;
      _microsPerIws = _microsPerDit * _iwsLen;
      // tick timing
      _ticksPerDit = _microsPerDit / _tick + 0.5;
      _ticksPerDah = _microsPerDit / _tick + 0.5;
      _ticksPerIes = _microsPerDit / _tick + 0.5;
      _ticksPerIls = _microsPerDit / _tick + 0.5;
      _ticksPerIws = _microsPerDit / _tick + 0.5;
    }
  }

 private:
  typedef enum {
    KEYER_OFF, KEYER_DIT, KEYER_DIT_SPACE, KEYER_DAH, KEYER_DAH_SPACE, KEYER_SYMBOL_SPACE, KEYER_WORD_SPACE,
  } keyerState;

  byte _rawDit;			// input dit state, unswapped
  byte _rawDah;			// input dah state, unswapped
  void (*_keyOut)(int on);	// output key state function

  float _tick;			// microseconds per tick
  bool _swapped;		// paddles are swapped
  bool _modeB;			// mode B or mode A
  float _word;			// dits per word, 50 or 60
  float _wpm;			// words per minute
  float _dahLen;		// dits per dah
  float _iesLen;		// dits per space between dits and dahs
  float _ilsLen;		// dits per space between letters
  float _iwsLen;		// dits per space between words
  bool _autoIls;		// automatically time space between letters
  bool _autoIws;		// automatically time space between words
  
  bool _update;			// update computed values
  byte _keyIn;			// input didah state, swapped
  byte _lastKeyIn;		// previous didah state
#define PREV_KEY_MASK 31
  byte _prevKeyInPtr;		// pointer to next slot in prevKey[]
  byte _prevKeyIn[32];		// previous didah state sampled 1/2 dit clock
  keyerState _keyerState;	// current keyer state
  int _halfClockDuration;	// ticks to next 1/2 dit clock transition
  int _keyerDuration;		// ticks to next keyer state transition

  // microseconds per feature
  float _microsPerDit;
  float _microsPerDah;
  float _microsPerIes;
  float _microsPerIls;
  float _microsPerIws;
  
  // ticks per feature
  int _ticksPerDit;
  int _ticksPerDah;
  int _ticksPerIes;
  int _ticksPerIls;
  int _ticksPerIws;

  void _restartHalfClock(byte keyIn) {
    _halfClockDuration = _ticksPerDit / 2;
    _prevKeyIn[_prevKeyInPtr++ & PREV_KEY_MASK] = keyIn;
  }

  // transition to the specified state
  // with the specified duration
  // and set the key out state
  bool _transitionTo(keyerState newState, int newDuration, bool keyOut) {
    if (_keyOut) _keyOut(keyOut ? 1 : 0);
    return _transitionTo(newState, newDuration);
  }
  
  // transition to the specified state
  // with the specified duration
  bool _transitionTo(keyerState newState, int newDuration) {
    _keyerState = newState;
    _keyerDuration += newDuration;
    return true;
  }

  // at the beginning of the next symbol
  // we may be currently at dit+dah, but
  // we want to start with which ever
  // paddle was pressed first
  bool _startSymbol() {
    if (_keyIn != KEYIN_DIDAH || _lastKeyIn != KEYIN_DAH)
      return _startDit() || _startDah();
    else
      return _startDah() || _startDit();
  }
  // start a dit if _dit is pressed
  bool _startDit() {
    return KEYIN_IS_DIT(_keyIn) && _transitionTo(KEYER_DIT, _ticksPerDit, true);
  }
  // start a dah if _dah is pressed or
  //   if _mode == KEYER_MODE_B and
  //   squeeze was released after the last element started and
  //   dah was next
  bool _startDah() {
    return KEYIN_IS_DAH(_keyIn) && _transitionTo(KEYER_DAH, _ticksPerDah, true);
  }
  // start an interelement space
  bool _startSpace(keyerState newState) {
    return _transitionTo(newState, _ticksPerIes, false);
  }
  // continue an interelement space to an intersymbol space
  // or an intersymbol space to an interword space
  bool _continueSpace(keyerState newState, int newDuration) {
    return _transitionTo(newState, newDuration);
  }
  // return to keyer idle state
  bool _finish() {
    return _transitionTo(KEYER_OFF, 0);
  }
};

#endif // Keyer_h
