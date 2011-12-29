/*
  Copyright (c) 2011 by Roger E Critchlow Jr, rec@elf.org

  Based on jack-1.9.8/example-clients/midiseq.c and
  dttsp-cgran-r624/src/keyboard-keyer.c

  jack-1.9.8/example-clients/midiseq.c is

    Copyright (C) 2004 Ian Esten

  dttsp-cgran-r624/src/keyboard-keyer.c

    Copyright (C) 2004, 2005, 2006, 2007, 2008 by Frank Brickle, AB2KT and Bob McGwier, N4HY
    Doxygen comments added by Dave Larsen, KV0S

  
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

//#define _POSIX_C_SOURCE 199309L
#include <jack/jack.h>
#include <jack/midiport.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <strings.h>
#include <math.h>

#include "keyer_options.h"
#include "keyer_midi.h"
#include "keyer_timing.h"
#include "keyer_framework.h"

typedef struct {
  keyer_timing_t samples_per;
  unsigned char note_on[3];
  unsigned char note_off[3];
  /* need to target sysex to the desired destination */
} ascii_data_t;

static keyer_framework_t fw;
static ascii_data_t data;

static void ascii_modified() {
  if (fw.opts.modified) {
    fw.opts.modified = 0;

    if (fw.opts.verbose > 2)
      fprintf(stderr, "recomputing data from options\n");

    /* update timing computations */
    keyer_timing_update(&fw.opts, &data.samples_per);

    /* midi note on/off */
    data.note_on[0] = NOTE_ON|(fw.opts.chan-1); data.note_on[1] = fw.opts.note;
    data.note_off[0] = NOTE_OFF|(fw.opts.chan-1); data.note_on[1] = fw.opts.note;

    /* pass on parameters to tone keyer */
    static keyer_options_t sent;
    char buffer[128];
    if (sent.rise != fw.opts.rise) { sprintf(buffer, "<rise%.1f>", sent.rise = fw.opts.rise); midi_sysex_write(buffer); }
    if (sent.fall != fw.opts.fall) { sprintf(buffer, "<fall%.1f>", sent.fall = fw.opts.fall); midi_sysex_write(buffer); }
    if (sent.freq != fw.opts.freq) { sprintf(buffer, "<freq%.1f>", sent.freq = fw.opts.freq); midi_sysex_write(buffer); }
    if (sent.gain != fw.opts.gain) { sprintf(buffer, "<gain%.1f>", sent.gain = fw.opts.gain); midi_sysex_write(buffer); }
  }
}

/*
** jack process callback
*/
static unsigned duration = 0;

static int ascii_process_callback(jack_nframes_t nframes, void *arg) {
  void* midi_out = jack_port_get_buffer(fw.midi_out, nframes);
  jack_midi_clear_buffer(midi_out);
  ascii_modified();
  /* for each frame in this callback */
  for(int i = 0; i < nframes; i += 1) {
    while (i == duration) {
      if (midi_readable()) {
	if (fw.opts.verbose > 4)
	  fprintf(stderr, "midi_readable, duration %u, count %u\n", midi_duration(), midi_count());
	duration += midi_duration();
	if (midi_count() != 0) {
	  unsigned count = midi_count();
	  unsigned char* buffer = jack_midi_event_reserve(midi_out, i, count);
	  if (buffer == NULL) {
	    fprintf(stderr, "jack won't buffer %d midi bytes!\n", count);
	  } else {
	    midi_read_bytes(count, buffer);
	    if (fw.opts.verbose > 4)
	      fprintf(stderr, "sent %x [%x, %x, %x, ...]\n", count, buffer[0], buffer[1], buffer[2]);
	  }
	}
	midi_read_next();
      } else {
	duration = nframes;
      }
    }
  }
  if (duration >= nframes)
    duration -= nframes;
  return 0;
}

/*
** translate queued characters into morse code key transitions
*/
static char *ascii_morse_table[128] = {
  /* 000 NUL */ 0, /* 001 SOH */ 0, /* 002 STX */ 0, /* 003 ETX */ 0,
  /* 004 EOT */ 0, /* 005 ENQ */ 0, /* 006 ACK */ 0, /* 007 BEL */ 0,
  /* 008  BS */ 0, /* 009  HT */ 0, /* 010  LF */ 0, /* 011  VT */ 0,
  /* 012  FF */ 0, /* 013  CR */ 0, /* 014  SO */ 0, /* 015  SI */ 0,
  /* 016 DLE */ 0, /* 017 DC1 */ 0, /* 018 DC2 */ 0, /* 019 DC3 */ 0,
  /* 020 DC4 */ 0, /* 021 NAK */ 0, /* 022 SYN */ 0, /* 023 ETB */ 0,
  /* 024 CAN */ 0, /* 025  EM */ 0, /* 026 SUB */ 0, /* 027 ESC */ 0,
  /* 028  FS */ 0, /* 029  GS */ 0, /* 030  RS */ 0, /* 031  US */ 0,
  /* 032  SP */ 0,
  /* 033   ! */ "...-.",	// [SN]
  /* 034   " */ ".-..-.",	// [RR]
  /* 035   # */ 0,
  /* 036   $ */ "...-..-",	// [SX]
  /* 037   % */ ".-...",	// [AS]
  /* 038   & */ 0,
  /* 039   ' */ ".----.",	// [WG]
  /* 040   ( */ "-.--.",	// [KN]
  /* 041   ) */ "-.--.-",	// [KK]
  /* 042   * */ "...-.-",	// [SK]
  /* 043   + */ ".-.-.",	// [AR]
  /* 044   , */ "--..--",
  /* 045   - */ "-....-",
  /* 046   . */ ".-.-.-",
  /* 047   / */ "-..-.",
  /* 048   0 */ "-----",
  /* 049   1 */ ".----",
  /* 050   2 */ "..---",
  /* 051   3 */ "...--",
  /* 052   4 */ "....-",
  /* 053   5 */ ".....",
  /* 054   6 */ "-....",
  /* 055   7 */ "--...",
  /* 056   8 */ "---..",
  /* 057   9 */ "----.",
  /* 058   : */ "---...",	// [OS]
  /* 059   ; */ "-.-.-.",	// [KR]
  /* 060   < */ 0,
  /* 061   = */ "-...-",	// [BT]
  /* 062   > */ 0,
  /* 063   ? */ "..--..",	// [IMI]
  /* 064   @ */ ".--.-.",
  /* 065   A */ ".-",
  /* 066   B */ "-...",
  /* 067   C */ "-.-.",
  /* 068   D */ "-..",
  /* 069   E */ ".",
  /* 070   F */ "..-.",
  /* 071   G */ "--.",
  /* 072   H */ "....",
  /* 073   I */ "..",
  /* 074   J */ ".---",
  /* 075   K */ "-.-",
  /* 076   L */ ".-..",
  /* 077   M */ "--",
  /* 078   N */ "-.",
  /* 079   O */ "---",
  /* 080   P */ ".--.",
  /* 081   Q */ "--.-",
  /* 082   R */ ".-.",
  /* 083   S */ "...",
  /* 084   T */ "-",
  /* 085   U */ "..-",
  /* 086   V */ "...-",
  /* 087   W */ ".--",
  /* 088   X */ "-..-",
  /* 089   Y */ "-.--",
  /* 090   Z */ "--..",
  /* 091   [ */ 0,
  /* 092   \ */ 0,
  /* 093   ] */ 0,
  /* 094   ^ */ 0,
  /* 095   _ */ "..--.-",	// [UK]
  /* 096   ` */ 0,
  /* 097   a */ ".-",
  /* 098   b */ "-...",
  /* 099   c */ "-.-.",
  /* 100   d */ "-..",
  /* 101   e */ ".",
  /* 102   f */ "..-.",
  /* 103   g */ "--.",
  /* 104   h */ "....",
  /* 105   i */ "..",
  /* 106   j */ ".---",
  /* 107   k */ "-.-",
  /* 108   l */ ".-..",
  /* 109   m */ "--",
  /* 110   n */ "-.",
  /* 111   o */ "---",
  /* 112   p */ ".--.",
  /* 113   q */ "--.-",
  /* 114   r */ ".-.",
  /* 115   s */ "...",
  /* 116   t */ "-",
  /* 117   u */ "..-",
  /* 118   v */ "...-",
  /* 119   w */ ".--",
  /* 120   x */ "-..-",
  /* 121   y */ "-.--",
  /* 122   z */ "--..",
  /* 123   { */ 0,
  /* 124   | */ 0,
  /* 125   } */ 0,
  /* 126   ~ */ 0,
  /* 127 DEL */ "........"
};

/*
** queue a string of . and - as midi events
** terminate with an inter letter space unless continues
*/
static void ascii_queue_midi(char c, char *p, int continues) {
  /* normal send single character */
  if (p == 0) {
    if (c == ' ')
      midi_write(data.samples_per.iws-data.samples_per.ils, 0, "");
  } else {
    while (*p != 0) {
      if (*p == '.') {
	midi_write(data.samples_per.dit, 3, data.note_on);
      } else if (*p == '-') {
	midi_write(data.samples_per.dah, 3, data.note_on);
      }
      if (p[1] != 0 || continues) {
	midi_write(data.samples_per.ies, 3, data.note_off);
      } else {
	midi_write(data.samples_per.ils, 3, data.note_off);
      }
      p += 1;
    }
  }
}

/*
** translate a single character into morse code
** but implement an escape to allow prosign construction
*/
static void ascii_queue_char(char c) {
  static char prosign[16], n_prosign, n_slash;
  if (c == '\\') {
    /* use \ab to send prosign a concatenated to b with no interletter space */
    /* multiple slashes to get longer prosigns, so \\sos or \s\os */
    n_slash += 1;
  } else if (n_slash != 0) {
    prosign[n_prosign++] = c;
    if (n_prosign == n_slash+1) {
      for (int i = 0; i < n_prosign; i += 1) {
	ascii_queue_midi(prosign[i], ascii_morse_table[prosign[i]&127], i != n_prosign-1);
      }
      n_prosign = 0;
      n_slash = 0;
    }
  } else {
    ascii_queue_midi(c, ascii_morse_table[c&0x7f], 0);
  }
}

int main(int argc, char **argv) {
  keyer_framework_main(&fw, argc, argv, "keyer_ascii", require_midi_out, ascii_process_callback, ascii_queue_char);
}
