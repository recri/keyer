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

ALL=../bin/keyer_tone ../bin/keyer_ascii ../bin/keyer_iambic ../bin/keyer_decode
ALL2=$(LIBDIR)/keyer_tone.so $(LIBDIR)/keyer_ascii.so $(LIBDIR)/keyer_iambic.so $(LIBDIR)/keyer_decode.so

all:: $(ALL) $(ALL2)
	cd $(LIBDIR) && make all

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

../bin/keyer_tone: keyer_tone.c framework.h options.h timing.h
	mkdir -p ../bin
	cc -o ../bin/keyer_tone $(CFLAGS) -DAS_BIN keyer_tone.c $(JACK_LIBS) -lm

../bin/keyer_decode: keyer_decode.c framework.h options.h
	mkdir -p ../bin
	cc -o ../bin/keyer_decode $(CFLAGS) -DAS_BIN keyer_decode.c  $(JACK_LIBS) -lm

../bin/keyer_ascii: keyer_ascii.c framework.h options.h timing.h midi.h
	mkdir -p ../bin
	cc -o ../bin/keyer_ascii $(CFLAGS) -DAS_BIN keyer_ascii.c $(JACK_LIBS) -lm

../bin/keyer_iambic: keyer_iambic.cc framework.h options.h timing.h midi.h
	mkdir -p ../bin
	g++ -o ../bin/keyer_iambic $(CPPFLAGS) -DAS_BIN keyer_iambic.cc $(JACK_LIBS) -lm

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h options.h timing.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_tone.so -shared -fPIC -DAS_TCL $(CFLAGS) keyer_tone.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_decode.so: keyer_decode.c framework.h options.h ring_buffer.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_decode.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_decode.c  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h options.h timing.h midi.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_ascii.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_ascii.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h options.h timing.h midi.h
	mkdir -p $(LIBDIR)
	g++ -o $(LIBDIR)/keyer_iambic.so $(CPPFLAGS) -shared -fPIC -DAS_TCL keyer_iambic.cc $(JACK_LIBS) $(LIBS) -lm

