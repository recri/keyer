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
#ifndef MIDI_H
#define MIDI_H

#ifdef __cplusplus
extern "C"
{
#endif

/*
** MIDI commands semi-implemented
** We use note-on and note-off to change logical signals.
** Most information travels as SYSEX strings.
** Our sysex is formatted:
** (uint8_t[]){
**	MIDI_SYSEX, MIDI_SYSEX_VENDOR, MIDI_SYSEX_SUBV1, MIDI_SYSEX_SUBV2, ..., MIDI_SYSEX_END
** }
** It appears as an educational, rather than a commercial, vendor.
** And it allows 14 bits of shared educational sysex address space.
**
** Within our payload we implement a simplified subset of Tcl commands in 7 bit ascii.
** So "set f 0x1339e0" would set a frequency to 1260 kHz.
*/
#define MIDI_NOTE_OFF		0x80
#define MIDI_NOTE_ON		0x90
#define MIDI_NOTE_AFTERTOUCH	0xA0
#define MIDI_CONTROL_CHANGE	0xB0
#define MIDI_PROGRAM_CHANGE	0xC0
#define MIDI_CHANNEL_PRESSURE	0xD0
#define MIDI_PITCHWHEEL_CHANGE	0xE0  
#define MIDI_SYSEX		0xF0
#define MIDI_SYSEX_VENDOR	0x7D /* this is the educational vendor id */
#define MIDI_SYSEX_SUBV1	0x7C
#define MIDI_SYSEX_SUBV2	0x7B
#define MIDI_SYSEX_END		0xF7

#ifdef __cplusplus
}
#endif

#endif
