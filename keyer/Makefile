#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 
CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.5

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)

LIBDIR=../lib/keyer

ALL=$(LIBDIR)/keyer_tone.so $(LIBDIR)/keyer_ascii.so $(LIBDIR)/keyer_iambic.so $(LIBDIR)/keyer_decode.so

all:: $(ALL) $(ALL2)
	cd $(LIBDIR) && make all

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h options.h ../dspkit/midi.h ../dspkit/keyed_tone.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_tone.so -shared -fPIC -DAS_TCL $(CFLAGS) keyer_tone.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_decode.so: keyer_decode.c framework.h options.h ../dspkit/midi.h ../dspkit/ring_buffer.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_decode.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_decode.c  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h options.h ../dspkit/midi.h ../dspkit/midi_buffer.h ../dspkit/morse_timing.h ../dspkit/morse_coding.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_ascii.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_ascii.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h options.h ../dspkit/midi.h ../dspkit/midi_buffer.h
	mkdir -p $(LIBDIR)
	g++ -o $(LIBDIR)/keyer_iambic.so $(CPPFLAGS) -shared -fPIC -DAS_TCL keyer_iambic.cc $(JACK_LIBS) $(LIBS) -lm

