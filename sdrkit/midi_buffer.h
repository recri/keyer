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

#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <jack/jack.h>
#include <jack/midiport.h>

#include "midi.h"
#include "ring_buffer.h"

/*
** midi buffering
**
** a circular buffer of midi events
** recording event durations and event contents
** intended for use by a single writer and single reader.
*/

typedef struct {
  unsigned duration;	  /* samples to next transition */
  unsigned short size;	  /* number of bytes, small number of bytes */
} midi_buffer_event_t;

#ifndef MIDI_BUFFER_BYTES
#define MIDI_BUFFER_BYTES	8192
#endif
#if MIDI_BUFFER_BYTES == 0 || (MIDI_BUFFER_BYTES & (MIDI_BUFFER_BYTES-1)) != 0
#error "MIDI_BUFFER_BYTES must postive and a power of two"
#endif

#ifndef MIDI_BUFFER_EVENT_BUFFER_SIZE
#define MIDI_BUFFER_EVENT_BUFFER_SIZE 64
#endif

typedef struct {
  ring_buffer_t ring;		/* main ring buffer */
  unsigned char buff[MIDI_BUFFER_BYTES];
  ring_buffer_t wring;		/* queued write buffer */
  unsigned char wbuff[MIDI_BUFFER_BYTES]; /* too big */
  ring_buffer_t rring;		/* queued read buffer */
  unsigned char rbuff[MIDI_BUFFER_BYTES]; /* also too big */
  jack_nframes_t head_frame;	/* frame time of read queue head */
  int event_count;		/* input event count */
  jack_midi_event_t events[MIDI_BUFFER_EVENT_BUFFER_SIZE];
} midi_buffer_t;

static void *midi_buffer_init(midi_buffer_t *bp) {
  void *p;
  p = ring_buffer_init(&bp->ring, MIDI_BUFFER_BYTES, bp->buff); if (p != &bp->ring) return p;
  p = ring_buffer_init(&bp->wring, MIDI_BUFFER_BYTES, bp->wbuff); if (p != &bp->wring) return p;
  p = ring_buffer_init(&bp->rring, MIDI_BUFFER_BYTES, bp->rbuff); if (p != &bp->rring) return p;
  bp->head_frame = 0;
  bp->event_count = 0;
  return bp;
}

/*
** midi read side
** this part is called from the jack process callback
*/
static void *midi_buffer_get_buffer(midi_buffer_t *bp, jack_nframes_t nframes, jack_nframes_t start_frame) {
  // clear the read ring for this chunk
  ring_buffer_reset(&bp->rring);

  // clear the available event counter
  bp->event_count = 0;


  // either we have a count down in progress, and bp->head_frame says when it fires,
  // or the first event fires immediately
  // if this is true, then there is an event and it is timed to happen
  // either within this chunk of frames or earlier
  midi_buffer_event_t e;
  while (bp->head_frame < start_frame + nframes && ring_buffer_items_available_to_read(&bp->ring) >= sizeof(e)) {
    // get the event header
    ring_buffer_get(&bp->ring, sizeof(e), (unsigned char *)&e);
    // set the event 
    bp->events[bp->event_count].time = (bp->head_frame > start_frame) ? (bp->head_frame - start_frame) : 0;
    bp->head_frame = start_frame + bp->events[bp->event_count].time; /* true time of this event */
    bp->events[bp->event_count].size = e.size;
    // get the event contents if any
    if (e.size != 0) {
      bp->events[bp->event_count].buffer = ring_buffer_put_ptr(&bp->rring);
      ring_buffer_get_to_ring(&bp->ring, e.size, &bp->rring);
    } else {
      bp->events[bp->event_count].buffer = NULL;
    }

    // use the event duration to update the head_frame
    // to set the sequence time of the next event
    if (bp->head_frame == 0)
      bp->head_frame = start_frame;
    bp->head_frame += e.duration;

    // increment the event counter for this chunk
    bp->event_count += 1;

    // look for overflow, can happen when a slider changes a lot
    if (bp->event_count >= MIDI_BUFFER_EVENT_BUFFER_SIZE) {
      fprintf(stderr, "%s:%d: midi buffer event buffer overflow\n", __FILE__, __LINE__);
      break;
    }
  }

  // return a pointer that can retrieve the dequeued events
  return (void *)bp;
}

static int midi_buffer_get_event_count(void *arg) {
  midi_buffer_t *bp = (midi_buffer_t *)arg;
  return bp->event_count;
}

static void midi_buffer_event_get(jack_midi_event_t *ep, void *arg, int eindex) {
  midi_buffer_t *bp = (midi_buffer_t *)arg;
  if (eindex < bp->event_count) {
    *ep = bp->events[eindex];
  } else {
    fprintf(stderr, "%s:%d: out of range midi_buffer_event_get %d >= %d\n", __FILE__, __LINE__, eindex, bp->event_count);
  }
}

/*
**
*/
static int midi_buffer_queue_bytes(midi_buffer_t *bp, unsigned char *bytes, int size) {
  if (ring_buffer_items_available_to_write(&bp->wring) < size)
    return -1;
  return ring_buffer_put(&bp->wring, size, bytes);
}

static int midi_buffer_queue_flush(midi_buffer_t *bp) {
  int size = ring_buffer_items_available_to_read(&bp->wring);
  if (ring_buffer_items_available_to_write(&bp->ring) < size)
    return -1;
  return ring_buffer_put_from_ring(&bp->ring, size, &bp->wring);
}

static int midi_buffer_queue_drop(midi_buffer_t *bp) {
  ring_buffer_reset(&bp->wring);
}

/*
** queue events, deferred flush.
**
** oops, small problem when the head of the queue gets written
** and it isn't an immediate event, ie a delay first:
** the head_frame doesn't get written to now+duration.
** and this code can't tell whether it's being called from background,
** where now=jack_frame_time, or from inside the process callback,
** where now=jack_last_frame+i.
**
** everything should be written with its time to fire, however determined,
** meaning no pure delays, sequence it out.
*/
static int midi_buffer_queue_command(midi_buffer_t *bp, unsigned duration, unsigned char *bytes, int size) {
  midi_buffer_event_t e;
  int n1, n2;
  e.duration = duration;
  e.size = size;
  n1 = midi_buffer_queue_bytes(bp, (unsigned char *)&e, sizeof(e));
  if (n1 < 0) return n1;
  n2 = midi_buffer_queue_bytes(bp, bytes, size);
  if (n2 < 0) return n2;
  return n1+n2;
}  
static int midi_buffer_queue_note_on(midi_buffer_t *bp, unsigned duration, int chan, int note, int vel) {
  midi_buffer_event_t e;
  unsigned char note_on[] = { MIDI_NOTE_ON|(chan-1), note, vel };
  return midi_buffer_queue_command(bp, duration, note_on, 3) > 0 ? 1 : -1;
}

static int midi_buffer_queue_note_off(midi_buffer_t *bp, unsigned duration, int chan, int note, int vel) {
  midi_buffer_event_t e;
  unsigned char note_off[] = { MIDI_NOTE_OFF|(chan-1), note, vel };
  return midi_buffer_queue_command(bp, duration, note_off, 3) > 0 ? 1 : -1;
}

static int midi_buffer_queue_delay(midi_buffer_t *bp, unsigned duration) {
  midi_buffer_event_t e;
  e.duration = duration;
  e.size = 0;
  return midi_buffer_queue_bytes(bp, (unsigned char *)&e, sizeof(e)) > 0 ? 1 : -1;
}

static int midi_buffer_queue_sysex(midi_buffer_t *bp, unsigned char *p) {
  midi_buffer_event_t e;
  static const unsigned char sysex_prefix[] = { MIDI_SYSEX, MIDI_SYSEX_VENDOR };
  static const unsigned char sysex_suffix[] = { MIDI_SYSEX_END };
  int n = strlen((char *)p);
  int n1, n2, n3, n4;
  e.duration = 0;
  e.size = sizeof(sysex_prefix)+n+sizeof(sysex_suffix);
  if (midi_buffer_queue_bytes(bp, (unsigned char *)&e, sizeof(e)) < 0) return -1;
  if (midi_buffer_queue_bytes(bp, (unsigned char *)sysex_prefix, sizeof(sysex_prefix)) < 0) return -1;
  if (midi_buffer_queue_bytes(bp, p, n) < 0) return -1;
  if (midi_buffer_queue_bytes(bp, (unsigned char *)sysex_suffix, sizeof(sysex_suffix)) < 0) return -1;
  return 1;
}
  
/*
** write events, queue and flush
*/
static int midi_buffer_write_command(midi_buffer_t *bp, unsigned duration, unsigned char *bytes, int count) {
  midi_buffer_queue_command(bp, duration, bytes, count);
  return midi_buffer_queue_flush(bp);
}

static int midi_buffer_write_note_on(midi_buffer_t *bp, unsigned duration, int chan, int note, int vel) {
  midi_buffer_queue_note_on(bp, duration, chan, note, vel);
  return midi_buffer_queue_flush(bp);
}

static int midi_buffer_write_note_off(midi_buffer_t *bp, unsigned duration, int chan, int note, int vel) {
  midi_buffer_queue_note_off(bp, duration, chan, note, vel);
  return midi_buffer_queue_flush(bp);
}

static int midi_buffer_write_delay(midi_buffer_t *bp, unsigned duration) {
  midi_buffer_queue_delay(bp, duration);
  return midi_buffer_queue_flush(bp);
}
  
static int midi_buffer_write_sysex(midi_buffer_t *bp, unsigned char *p) {
  midi_buffer_queue_sysex(bp, p);
  return midi_buffer_queue_flush(bp);
}

/*
** routines for implementing pending and avaialble
*/
static int midi_buffer_readable(midi_buffer_t *bp) {
  return ring_buffer_items_available_to_read(&bp->ring);
}

static int midi_buffer_writeable(midi_buffer_t *bp) {
  return ring_buffer_items_available_to_write(&bp->ring);
}
#endif
