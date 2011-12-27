#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <jack/jack.h>

#include "keyer_options.h"
#include "keyer_midi.h"

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

/*
** midi buffering
** a circular buffer of midi event headers
** recording event durations and event contents
** a circular buffer of bytes to store event contents
*/

typedef struct {
  unsigned duration;	  /* samples to next transition */
  unsigned short index;	  /* index into midi_byte_buffer */
  unsigned short count;	  /* number of bytes, small number of bytes */
} midi_event_t;

#define MIDI_EVENTS	1024
#if ! ((MIDI_EVENTS > 128) && ((MIDI_EVENTS & (MIDI_EVENTS-1)) == 0))
#error "MIDI_EVENTS must be > 128 and a power of two"
#endif
static midi_event_t midi_event[MIDI_EVENTS];
static unsigned short midi_write_ptr = 0;
static unsigned short midi_read_ptr = 0;

#define MIDI_BYTES	8192
#if ! ((MIDI_BYTES >= 4*MIDI_EVENTS) && ((MIDI_BYTES & (MIDI_BYTES-1)) == 0))
#error "MIDI_BYTES must be >= 4*MIDI_EVENTS and a power of two"
#endif
static unsigned char midi_byte[MIDI_BYTES];
static unsigned short midi_byte_write_ptr = 0;
static unsigned short midi_byte_read_ptr = 0;

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
int midi_readable() {
  return buffer_readable(midi_write_ptr, midi_read_ptr, MIDI_EVENTS);
}

static int midi_bytes_readable(int count) {
  return buffer_items_available_to_read(midi_byte_write_ptr, midi_byte_read_ptr, MIDI_BYTES) >= count;
}

unsigned midi_duration() {
  return midi_readable() ? midi_event[midi_index(midi_read_ptr)].duration : 0;
}

unsigned short midi_count() {
  return midi_readable() ? midi_event[midi_index(midi_read_ptr)].count : 0;
}

void midi_read_bytes(short count, unsigned char *bytes) {
  if (midi_readable() && midi_bytes_readable(count))
    for (int i = 0; i < count; i += 1)
      bytes[i] = midi_byte[midi_byte_index(midi_event[midi_index(midi_read_ptr)].index+i)];
}

void midi_read_next() {
  if (midi_readable()) {
    midi_byte_read_ptr += midi_count();
    midi_read_ptr += 1;
  }
}

/*
** midi write side
** this part is called from outside the jack process callback
*/
static int midi_writeable() {
  return buffer_writeable(midi_write_ptr, midi_read_ptr, MIDI_EVENTS);
}

static int midi_bytes_writeable(unsigned count) {
  return buffer_items_available_to_write(midi_byte_write_ptr, midi_byte_read_ptr, MIDI_BYTES) >= count;
}

static unsigned midi_write_bytes(short count, unsigned char *bytes) {
  unsigned index = midi_byte_index(midi_byte_write_ptr);
  for (int i = 0; i < count; i += 1)
    midi_byte[midi_byte_index(midi_byte_write_ptr++)] = bytes[i];
  return index;
}

void midi_write(unsigned duration, short count, unsigned char *bytes) {
  if ( ! (midi_writeable() && midi_bytes_writeable(count))) {
    fprintf(stderr, "stalling in midi_write\n");
    int i;
    for (i = 0; ! (midi_writeable() && midi_bytes_writeable(count)); i += 1)
      sleep(1);
    fprintf(stderr, "stalled %d seconds in midi_write\n", i);
  }
  midi_event_t *mp = &midi_event[midi_index(midi_write_ptr)];
  mp->duration = duration;
  mp->count = count;
  mp->index = midi_write_bytes(count, bytes);
  midi_write_ptr += 1;
  // fprintf(stderr, "midi_write(%u, %d, [%02x, %02x, %02x, ...]\n", duration, count, bytes[0], bytes[1], bytes[2]);
}

/*
** construct and send a sysex
*/
void midi_sysex_write(char *p) {
  char buff[256];
  int n = strlen(p);
  if (n+3 > sizeof(buff)) {
    fprintf(stderr, "sysex is too large: %s\n", p);
  } else {
    buff[0] = SYSEX;
    buff[1] = SYSEX_VENDOR;
    strcpy(buff+2, p);
    buff[2+n] = SYSEX_END;
    midi_write(0, n+3, buff);
  }
}
  
