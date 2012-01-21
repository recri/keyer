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
#ifndef FLOAT_RING_BUFFER_H
#define FLOAT_RING_BUFFER_H

/*
** float ring buffer
**
** this is intended for transferring data between one reader and one writer
** where the reader and writer may not be synchronized.
*/
typedef struct {
  unsigned wptr;		/* write pointer */
  unsigned rptr;		/* read pointer */
  unsigned size;		/* number of elements */
  unsigned mask;		/* buffer index mask */
  float *buff;			/* buffer of stuff */
} float_ring_buffer_t;
typedef struct {
  unsigned size;
  float *buff;
} float_ring_buffer_options_t;

// returns p on success, otherwise an error string
static void *float_ring_buffer_init(float_ring_buffer_t *p, unsigned size, float *buff) {
  if (! size) return (void *)"size must be positive";
  if (((size-1) & size) != 0) return (void *)"size must be a power of two";
  p->size = size;
  p->mask = size-1;
  p->buff = buff;
  p->wptr = p->rptr = 0;
  return p;
}

static void float_ring_buffer_reset(float_ring_buffer_t *p) {
  p->wptr = p->rptr = 0;
}

static unsigned float_ring_buffer_items_available_to_read(float_ring_buffer_t *p) { return p->wptr-p->rptr; }
static unsigned float_ring_buffer_items_available_to_write(float_ring_buffer_t *p) { return p->size-float_ring_buffer_items_available_to_read(p); }
static unsigned float_ring_buffer_readable(float_ring_buffer_t *p) { return float_ring_buffer_items_available_to_read(p) > 0; }
static unsigned float_ring_buffer_writeable(float_ring_buffer_t *p) { return float_ring_buffer_items_available_to_write(p) > 0; }
static unsigned float_ring_buffer_index(float_ring_buffer_t *p, unsigned ptr) { return (ptr&(p->size-1)); }

static int float_ring_buffer_get(float_ring_buffer_t *p, unsigned size, float *floats) {
  if (float_ring_buffer_items_available_to_read(p) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    floats[i] = p->buff[float_ring_buffer_index(p, p->rptr+i)];
  p->rptr += size;
  return size;
}
  
static int float_ring_buffer_get_to_ring(float_ring_buffer_t *src, unsigned size, float_ring_buffer_t *dst) {
  if (float_ring_buffer_items_available_to_read(src) < size || float_ring_buffer_items_available_to_write(dst) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    dst->buff[float_ring_buffer_index(dst, dst->wptr+i)] = src->buff[float_ring_buffer_index(src, src->rptr+i)];
  src->rptr += size;
  dst->wptr += size;
  return size;
}
  
static float *float_ring_buffer_put_ptr(float_ring_buffer_t *p) {
  return &p->buff[float_ring_buffer_index(p, p->wptr)];
}

static int float_ring_buffer_put(float_ring_buffer_t *p, unsigned size, float *floats) {
  if (float_ring_buffer_items_available_to_write(p) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    p->buff[float_ring_buffer_index(p, p->wptr+i)] = floats[i];
  p->wptr += size;
  return size;
}

static int float_ring_buffer_put_from_ring(float_ring_buffer_t *dst, unsigned size, float_ring_buffer_t *src) {
  if (float_ring_buffer_items_available_to_write(dst) < size || float_ring_buffer_items_available_to_read(src) < size)
    return -1;
  for (int i = 0; i < size; i += 1)
    dst->buff[float_ring_buffer_index(dst, dst->wptr+i)] = src->buff[float_ring_buffer_index(src, src->rptr+i)];
  src->rptr += size;
  dst->wptr += size;
  return size;
}

#endif
