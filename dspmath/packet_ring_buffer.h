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
#ifndef PACKET_RING_BUFFER_H
#define PACKET_RING_BUFFER_H
/*
** ring buffers for shuffling byte arrays between threads
**
** the 'packets' are Tcl ByteArray objects. The contents are
** uninteresting to this package.  This package simply arranges
** to store them in a lock free ringbuffer so they may be safely
** moved between threads.  The should be
*/
#ifndef PACKET_RING_SIZE
#define PACKET_RING_SIZE 64	/* must be power of two */
#endif

/* #assert(PACKET_RING_SIZE > 1) */
/* #assert((PACKET_RING_SIZE & (PACKET_RING_SIZE-1)) == 0) */
typedef struct {
  Tcl_Obj *ring[PACKET_RING_SIZE];
  unsigned short rdptr, wrptr;
} packet_ring_buffer_t;
static inline void packet_ring_buffer_init(packet_ring_buffer_t *rb) { rb->rdptr = rb->wrptr = 0; }
static inline int packet_ring_buffer_can_read(packet_ring_buffer_t *rb) { return (rb->wrptr - rb->rdptr)&(PACKET_RING_SIZE-1); }
static inline Tcl_Obj *packet_ring_buffer_read(packet_ring_buffer_t *rb) { return rb->ring[rb->rdptr++&(PACKET_RING_SIZE-1)]; }
static inline int packet_ring_buffer_can_write(packet_ring_buffer_t *rb) { return PACKET_RING_SIZE-packet_ring_buffer_can_read(rb); }
static inline void packet_ring_buffer_write(packet_ring_buffer_t *rb, Tcl_Obj *obj) { rb->ring[rb->wrptr++&(PACKET_RING_SIZE-1)] = obj; }

#endif
