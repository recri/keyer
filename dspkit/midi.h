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
*/
#define MIDI_NOTE_OFF		0x80
#define MIDI_NOTE_ON		0x90
#define MIDI_NOTE_TOUCH		0xA0
#define MIDI_CHAN_CONTROL	0xB0
#define MIDI_SYSEX		0xF0
#define MIDI_SYSEX_VENDOR	0x7D
#define MIDI_SYSEX_END		0xF7

#ifdef __cplusplus
}
#endif

#endif
