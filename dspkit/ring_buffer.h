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
** ring buffer
**
** this is intended for transferring data between one reader and one writer
** where the reader and writer may not be synchronized.
*/
typedef struct {
  unsigned wptr;		/* write pointer */
  unsigned rptr;		/* read pointer */
  unsigned size;		/* number of elements */
  unsigned mask;		/* buffer index mask */
  unsigned char *buff;		/* buffer of stuff */
} ring_buffer_t;

// returns p on success, otherwise an error string
static void *ring_buffer_init(ring_buffer_t *p, unsigned size, unsigned char *buff) {
  if (! size) return (void *)"size must be positive";
  if (((size-1) & size) != 0) return (void *)"size must be a power of two";
  p->size = size;
  p->mask = size-1;
  p->buff = buff;
  p->wptr = p->rptr = 0;
  return p;
}

static void ring_buffer_reset(ring_buffer_t *p) {
  p->wptr = p->rptr = 0;
}

static unsigned ring_buffer_items_available_to_read(ring_buffer_t *p) { return p->wptr-p->rptr; }
static unsigned ring_buffer_items_available_to_write(ring_buffer_t *p) { return p->size-ring_buffer_items_available_to_read(p); }
static unsigned ring_buffer_readable(ring_buffer_t *p) { return ring_buffer_items_available_to_read(p) > 0; }
static unsigned ring_buffer_writeable(ring_buffer_t *p) { return ring_buffer_items_available_to_write(p) > 0; }
static unsigned ring_buffer_index(ring_buffer_t *p, unsigned ptr) { return (ptr&(p->size-1)); }

static int ring_buffer_get(ring_buffer_t *p, unsigned size, unsigned char *bytes) {
  if (ring_buffer_items_available_to_read(p) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    bytes[i] = p->buff[ring_buffer_index(p, p->rptr+i)];
  p->rptr += size;
  return size;
}
  
static int ring_buffer_get_to_ring(ring_buffer_t *src, unsigned size, ring_buffer_t *dst) {
  if (ring_buffer_items_available_to_read(src) < size || ring_buffer_items_available_to_write(dst) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    dst->buff[ring_buffer_index(dst, dst->wptr+i)] = src->buff[ring_buffer_index(src, src->rptr+i)];
  src->rptr += size;
  dst->wptr += size;
  return size;
}
  
static unsigned char *ring_buffer_put_ptr(ring_buffer_t *p) {
  return &p->buff[ring_buffer_index(p, p->wptr)];
}

static int ring_buffer_put(ring_buffer_t *p, unsigned size, unsigned char *bytes) {
  if (ring_buffer_items_available_to_write(p) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    p->buff[ring_buffer_index(p, p->wptr+i)] = bytes[i];
  p->wptr += size;
  return size;
}

static int ring_buffer_put_from_ring(ring_buffer_t *dst, unsigned size, ring_buffer_t *src) {
  if (ring_buffer_items_available_to_write(dst) < size || ring_buffer_items_available_to_read(src) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    dst->buff[ring_buffer_index(dst, dst->wptr+i)] = src->buff[ring_buffer_index(src, src->rptr+i)];
  src->rptr += size;
  dst->wptr += size;
  return size;
}

#endif
