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
