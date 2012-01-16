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
