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
** and by '!' to indicate encoded as nibbles using ascii 'a' .. 'p' to encode 0 .. 15
** or by '"' to indicate literal text commands
*/
#define MIDIKEYSR_SET_DEVICE		0 /* device_type_t value */
#define MIDIKEYSR_I2C_PROBE		1 /* probe i2c address */
#define MIDIKEYSR_I2C_SEND		2 /* send i2c address, value, ... */
#define MIDIKEYSR_I2C_RECV		3 /* recv i2c address, from_value, ... */
#define MIDIKEYSR_SI570_FREEZE_DCO	4 /*  */
#define MIDIKEYSR_SI570_UNFREEZE_DCO	5 /*  */
#define MIDIKEYSR_SI570_NEW_FREQ	6 /*  */
#define MIDIKEYER_SI570_RECALL_F0	7 /*  */

#define MAX_SYSEX	32		  /* maximum size of sysex, including }! prefix */

// device identification, comes through MIDI
typedef enum {
  no_device = 0,
  rx_device = 1,
  rxtx_device = 2
} device_type_t;

#ifdef __cplusplus
}
#endif

#endif
