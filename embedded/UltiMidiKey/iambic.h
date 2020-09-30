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
#ifndef IAMBIC_H
#define IAMBIC_H

/*
** the iambic keyers are structured so that one calls
** keyer.clock(dit, dah, ticks) to supply the current 
** values of the dit and dah paddles and the number of
** ticks elapsed since the last call.
**
** keyer.clock returns the keyout state, which has been
** on or off if keyout != 0 or keyout == 0.
**
** now it can be dit_on or dah_on or off, which still reads
** the same as before if that's all you care about.
*/

#define IAMBIC_OFF 0
#define IAMBIC_KEY 1
#define IAMBIC_DIT 3
#define IAMBIC_DAH 5

#endif
