CFLAGS=-std=c99 -g -O3 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.6

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)

ALL=../bin/keyer_tone ../bin/keyer_ascii ../bin/keyer_iambic ../bin/keyer_decode ../bin/keyer_iambic2

all: $(ALL)

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

../bin/keyer_tone: keyer_tone.c keyer_options.o keyer_framework.o keyer_timing.h
	mkdir -p ../bin
	cc -o ../bin/keyer_tone $(CFLAGS) keyer_tone.c keyer_options.o keyer_framework.o $(JACK_LIBS) -lm

../bin/keyer_decode: keyer_decode.c keyer_options.o keyer_framework.o
	mkdir -p ../bin
	cc -o ../bin/keyer_decode $(CFLAGS) keyer_decode.c keyer_options.o keyer_framework.o $(JACK_LIBS) -lm

../bin/keyer_ascii: keyer_ascii.c keyer_options.o keyer_midi.o keyer_framework.o keyer_timing.h
	mkdir -p ../bin
	cc -o ../bin/keyer_ascii $(CFLAGS) keyer_ascii.c keyer_options.o keyer_midi.o keyer_framework.o $(JACK_LIBS) -lm

../bin/keyer_iambic: keyer_iambic.c keyer_options.o keyer_midi.o keyer_framework.o keyer_timing.h
	mkdir -p ../bin
	cc -o ../bin/keyer_iambic $(CFLAGS) keyer_iambic.c keyer_options.o keyer_midi.o keyer_framework.o $(JACK_LIBS) -lm

../bin/keyer_iambic2: keyer_iambic2.cc keyer_options.o keyer_midi.o keyer_framework.o keyer_timing.h KeyerIambic.hh
	mkdir -p ../bin
	g++ -o ../bin/keyer_iambic2 $(CPPFLAGS) keyer_iambic2.cc keyer_options.o keyer_midi.o keyer_framework.o $(JACK_LIBS) -lm

keyer_options.o: keyer_options.c keyer_options.h
	cc -c $(CFLAGS) keyer_options.c

keyer_midi.o: keyer_midi.c keyer_midi.h
	cc -c $(CFLAGS) keyer_midi.c

keyer_framework.o: keyer_framework.c keyer_framework.h
	cc -c $(CFLAGS) keyer_framework.c
