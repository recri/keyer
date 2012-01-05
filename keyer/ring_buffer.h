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
#ifndef RING_BUFFER_H
#define RING_BUFFER_H

/*
** circular buffer arithmetic
*/

static unsigned buffer_items_available_to_read(unsigned wptr, unsigned rptr, unsigned size) {
  return wptr-rptr;
}

static unsigned buffer_items_available_to_write(unsigned wptr, unsigned rptr, unsigned size) {
  return size-buffer_items_available_to_read(wptr, rptr, size);
}

static int buffer_readable(unsigned wptr, unsigned rptr, unsigned size) {
  return buffer_items_available_to_read(wptr, rptr, size) > 0;
}

static int buffer_writeable(unsigned wptr, unsigned rptr, unsigned size) {
  return buffer_items_available_to_write(wptr, rptr, size) > 0;
}

static unsigned buffer_index(unsigned ptr, unsigned size) {
  return (ptr&(size-1));
}

#endif
