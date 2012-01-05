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
#ifndef MIDI_BUFFER_H
#define MIDI_BUFFER_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <jack/jack.h>

#include "midi.h"
#include "ring_buffer.h"

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
#define MIDI_BYTES	8192
#if ! ((MIDI_BYTES >= 4*MIDI_EVENTS) && ((MIDI_BYTES & (MIDI_BYTES-1)) == 0))
#error "MIDI_BYTES must be >= 4*MIDI_EVENTS and a power of two"
#endif

typedef struct {
  midi_event_t midi_event[MIDI_EVENTS];
  unsigned short midi_write_ptr;
  unsigned short midi_read_ptr;

  unsigned char midi_byte[MIDI_BYTES];
  unsigned short midi_byte_write_ptr;
  unsigned short midi_byte_read_ptr;
} midi_buffer_t;

static void midi_init(midi_buffer_t *bp) {
  bp->midi_write_ptr = 0;
  bp->midi_read_ptr = 0;
  bp->midi_byte_write_ptr = 0;
  bp->midi_byte_read_ptr = 0;
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
static int midi_n_readable(midi_buffer_t *bp) {
  return buffer_items_available_to_read(bp->midi_write_ptr, bp->midi_read_ptr, MIDI_EVENTS);
}

static int midi_readable(midi_buffer_t *bp) {
  return buffer_readable(bp->midi_write_ptr, bp->midi_read_ptr, MIDI_EVENTS);
}

static int midi_n_bytes_readable(midi_buffer_t *bp) {
  return buffer_items_available_to_read(bp->midi_byte_write_ptr, bp->midi_byte_read_ptr, MIDI_BYTES);
}

static int midi_bytes_readable(midi_buffer_t *bp, int count) {
  return midi_n_bytes_readable(bp) >= count;
}

static unsigned midi_duration(midi_buffer_t *bp) {
  return midi_readable(bp) ? bp->midi_event[midi_index(bp->midi_read_ptr)].duration : 0;
}

static unsigned short midi_count(midi_buffer_t *bp) {
  return midi_readable(bp) ? bp->midi_event[midi_index(bp->midi_read_ptr)].count : 0;
}

static void midi_read_bytes(midi_buffer_t *bp, short count, unsigned char *bytes) {
  if (midi_readable(bp) && midi_bytes_readable(bp, count))
    for (int i = 0; i < count; i += 1)
      bytes[i] = bp->midi_byte[midi_byte_index(bp->midi_event[midi_index(bp->midi_read_ptr)].index+i)];
}

static void midi_read_next(midi_buffer_t *bp) {
  if (midi_readable(bp)) {
    bp->midi_byte_read_ptr += midi_count(bp);
    bp->midi_read_ptr += 1;
  }
}

/*
** midi write side
** this part is called from outside the jack process callback
*/
static int midi_n_writeable(midi_buffer_t *bp) {
  return buffer_items_available_to_write(bp->midi_write_ptr, bp->midi_read_ptr, MIDI_EVENTS);
}

static int midi_writeable(midi_buffer_t *bp) {
  return buffer_writeable(bp->midi_write_ptr, bp->midi_read_ptr, MIDI_EVENTS);
}

static int midi_n_bytes_writeable(midi_buffer_t *bp) {
  return buffer_items_available_to_write(bp->midi_byte_write_ptr, bp->midi_byte_read_ptr, MIDI_BYTES);
}

static int midi_bytes_writeable(midi_buffer_t *bp, unsigned count) {
  return midi_n_bytes_writeable(bp) >= count;
}

static unsigned midi_write_bytes(midi_buffer_t *bp, short count, unsigned char *bytes) {
  unsigned index = midi_byte_index(bp->midi_byte_write_ptr);
  for (int i = 0; i < count; i += 1)
    bp->midi_byte[midi_byte_index(bp->midi_byte_write_ptr++)] = bytes[i];
  return index;
}

static void midi_write(midi_buffer_t *bp, unsigned duration, short count, unsigned char *bytes) {
  if ( ! (midi_writeable(bp) && midi_bytes_writeable(bp, count))) {
    fprintf(stderr, "stalling in midi_write\n");
    int i;
    for (i = 0; ! (midi_writeable(bp) && midi_bytes_writeable(bp, count)); i += 1)
      sleep(1);
    fprintf(stderr, "stalled %d seconds in midi_write\n", i);
  }
  midi_event_t *mp = &bp->midi_event[midi_index(bp->midi_write_ptr)];
  mp->duration = duration;
  mp->count = count;
  mp->index = midi_write_bytes(bp, count, bytes);
  bp->midi_write_ptr += 1;
  // fprintf(stderr, "midi_write(%u, %d, [%02x, %02x, %02x, ...]\n", duration, count, bytes[0], bytes[1], bytes[2]);
}

/*
** construct and send a sysex
*/
static void midi_sysex_write(midi_buffer_t *bp, char *p) {
  unsigned char buff[256];
  int n = strlen(p);
  if (n+3 > sizeof(buff)) {
    fprintf(stderr, "sysex is too large: %s\n", p);
  } else {
    buff[0] = SYSEX;
    buff[1] = SYSEX_VENDOR;
    strcpy((char *)buff+2, p);
    buff[2+n] = SYSEX_END;
    midi_write(bp, 0, n+3, buff);
  }
}
  
#ifdef __cplusplus
}
#endif

#endif
