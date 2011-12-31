#ifndef DEBOUNCE_HH
#define DEBOUNCE_HH
/*
** A switch debouncer class.
**
** transition when the new value has been
** stable for "steps" observations, "steps" <= 32.
** 
*/

class Debounce {
 public:
  Debounce(byte steps) : _mask((1L<<(steps-1))-1) {
    _filter = 0L;
    _value = 0;
  }

  // debounce by recording a stream of bits which will be all zero
  // when the switch has settled into the other state
  byte debounce(byte input) {
    _filter = (_filter << 1) | (input ^ _value ^ 1);
    return _value = ((_filter & _mask) == 0) ? input : _value;
  }

 private:
  byte _value;
  unsigned long _filter;
  const unsigned long _mask;

};

#endif
