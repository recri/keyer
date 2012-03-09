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
#ifndef MIDIKEYSR_H
#define MIDIKEYSR_H

#ifdef __cplusplus
extern "C"
{
#endif

/*
** MidiKeySR SysExcommands
** prefixed by sysex vendor 0x7D, educational '}'
** and by '!' to indicate our flavor of commands
** encoded as nibbles using
** ascii '0','1','2','3','4','5','6','7','8','9',':',';','<','=','>', and '?'
** to encode 0 .. 15
** packed back into byte values, first byte is command, remainder are parameters.
*/
#define MIDIKEYSR_I2C_SCAN		0 /* scan i2c bus for actives, return bit map */
#define MIDIKEYSR_I2C_SEND		1 /* send i2c address, value, ... */
#define MIDIKEYSR_I2C_RECV		2 /* recv i2c address, nbytes */
#define MIDIKEYSR_SI570_FREEZE_DCO	3 /*  */
#define MIDIKEYSR_SI570_UNFREEZE_DCO	4 /*  */
#define MIDIKEYSR_SI570_SET_REGS	5 /*  */
#define MIDIKEYSR_SI570_GET_REGS	6 /*  */
#define MIDIKEYSR_SI570_NEW_FREQ	7 /*  */
#define MIDIKEYER_SI570_RECALL_F0	8 /*  */

// device identification, comes through MIDI
typedef enum {
  no_device = 0,
  rx_device = 1,
  rxtx_device = 2
} device_type_t

#ifdef __cplusplus
}
#endif

#endif
