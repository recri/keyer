#ifndef SDRKIT_MIDI_QUEUE_H
#define SDRKIT_MIDI_QUEUE_H

#include <jack/jack.h>
#include <jack/midiport.h>

/*
** circular buffer arithmetic
*/

static unsigned buffer_index(unsigned ptr, unsigned size) {
  return (ptr&(size-1));
}

static unsigned buffer_items_available_to_read(unsigned wptr, unsigned rptr, unsigned size) {
  return wptr-rptr;
}

static unsigned buffer_items_consecutive_available_to_read(unsigned wptr, unsigned rptr, unsigned size) {
  return size-buffer_index(rptr, size);
}

static unsigned buffer_items_available_to_write(unsigned wptr, unsigned rptr, unsigned size) {
  return size-buffer_items_available_to_read(wptr, rptr, size);
}

static unsigned buffer_items_consecutive_available_to_write(unsigned wptr, unsigned rptr, unsigned size) {
  return size-buffer_index(wptr, size);
}

static int buffer_readable(unsigned wptr, unsigned rptr, unsigned size) {
  return buffer_items_available_to_read(wptr, rptr, size) > 0;
}

static int buffer_writeable(unsigned wptr, unsigned rptr, unsigned size) {
  return buffer_items_available_to_write(wptr, rptr, size) > 0;
}

/*
** midi buffering
** a circular buffer of midi event headers
** recording event times and event contents
** a circular buffer of bytes to store event contents
*/

typedef struct {
  jack_nframes_t time;	  /* jack sample time of this event */
  unsigned short index;	  /* index into midi_byte_buffer */
  unsigned short size;	  /* number of bytes, small number of bytes */
} midi_event_t;

#define MIDI_EVENTS	1024
#if ! ((MIDI_EVENTS > 128) && ((MIDI_EVENTS & (MIDI_EVENTS-1)) == 0))
#error "MIDI_EVENTS must be > 128 and a power of two"
#endif

#define MIDI_BYTES	8192
#if ! ((MIDI_BYTES >= 4*MIDI_EVENTS) && ((MIDI_BYTES & (MIDI_BYTES-1)) == 0))
#error "MIDI_BYTES must be >= 4*MIDI_EVENTS and a power of two"
#endif

typedef struct {
  unsigned long lost;
  unsigned short midi_write_ptr;
  unsigned short midi_read_ptr;
  unsigned short midi_byte_write_ptr;
  unsigned short midi_byte_read_ptr;
  midi_event_t midi_event[MIDI_EVENTS];
  unsigned char midi_byte[MIDI_BYTES];
} midi_queue_t;

static void midi_queue_init(midi_queue_t *q) {
  q->lost = 0;
  q->midi_write_ptr = 0;
  q->midi_read_ptr = 0;
  q->midi_byte_write_ptr = 0;
  q->midi_byte_read_ptr = 0;
}
  
/*
** midi common
*/
static unsigned midi_index(unsigned ptr) {
  return buffer_index(ptr, MIDI_EVENTS);
}

static unsigned midi_byte_index(unsigned ptr) {
  return buffer_index(ptr, MIDI_BYTES);
}

/*
** midi read side
** this part is called from the jack process callback
*/
int midi_readable(midi_queue_t *q) {
  return buffer_readable(q->midi_write_ptr, q->midi_read_ptr, MIDI_EVENTS);
}

static int midi_bytes_readable(midi_queue_t *q, int size) {
  return buffer_items_available_to_read(q->midi_byte_write_ptr, q->midi_byte_read_ptr, MIDI_BYTES) >= size;
}

/* only true if midi_bytes_readable true for same arguments */
static int midi_bytes_consecutive_readable(midi_queue_t *q, int size) {
  return buffer_items_consecutive_available_to_read(q->midi_byte_write_ptr, q->midi_byte_read_ptr, MIDI_BYTES) >= size;
}

unsigned midi_read_time(midi_queue_t *q) {
  return midi_readable(q) ? q->midi_event[midi_index(q->midi_read_ptr)].time : 0;
}

unsigned short midi_read_size(midi_queue_t *q) {
  return midi_readable(q) ? q->midi_event[midi_index(q->midi_read_ptr)].size : 0;
}

void midi_read_bytes(midi_queue_t *q, short size, unsigned char *bytes) {
  if (midi_readable(q) && midi_bytes_readable(q, size))
    for (int i = 0; i < size; i += 1)
      bytes[i] = q->midi_byte[midi_byte_index(q->midi_event[midi_index(q->midi_read_ptr)].index+i)];
}

unsigned char *midi_read_bytes_ptr(midi_queue_t *q, short size) {
  if (midi_readable(q) && midi_bytes_readable(q, size) && midi_bytes_consecutive_readable(q, size))
    return &q->midi_byte[midi_byte_index(q->midi_event[midi_index(q->midi_read_ptr)].index)];
}
  
void midi_read_next(midi_queue_t *q) {
  if (midi_readable(q)) {
    q->midi_byte_read_ptr += midi_read_size(q);
    q->midi_read_ptr += 1;
  }
}

/*
** midi write side
** this part is called from outside the jack process callback
*/
static int midi_writeable(midi_queue_t *q) {
  return buffer_writeable(q->midi_write_ptr, q->midi_read_ptr, MIDI_EVENTS);
}

static int midi_bytes_writeable(midi_queue_t *q, unsigned size) {
  return buffer_items_available_to_write(q->midi_byte_write_ptr, q->midi_byte_read_ptr, MIDI_BYTES) >= size;
}

static int midi_bytes_writeable_consecutive(midi_queue_t *q, unsigned size) {
  return buffer_items_consecutive_available_to_write(q->midi_byte_write_ptr, q->midi_byte_read_ptr, MIDI_BYTES) >= size;
}

static unsigned midi_write_bytes(midi_queue_t *q, short size, unsigned char *bytes) {
  unsigned index = midi_byte_index(q->midi_byte_write_ptr);
  for (int i = 0; i < size; i += 1)
    q->midi_byte[midi_byte_index(q->midi_byte_write_ptr++)] = bytes[i];
  return index;
}

int midi_write(midi_queue_t *q, jack_nframes_t time, short size, unsigned char *bytes) {
  if ( ! midi_writeable(q)) {
    q->lost += 1;
    return 0;
  }
  if ( ! midi_bytes_writeable(q, size)) {
    q->lost += 1;
    return 0;
  }
  if ( ! midi_bytes_writeable_consecutive(q, size)) {
    if ( ! midi_bytes_writeable(q, 2*size)) {
      q->lost += 1;
      return 0;
    }
    q->midi_byte_write_ptr |= MIDI_BYTES-1;
  }
  midi_event_t *mp = &q->midi_event[midi_index(q->midi_write_ptr)];
  mp->time = time;
  mp->size = size;
  mp->index = midi_write_bytes(q, size, bytes);
  q->midi_write_ptr += 1;
  return 1;
}

#endif
