CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.5

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)

LIBDIR=../lib/sdrkit

ALL=$(LIBDIR)/sdrkit_agc.so \
	$(LIBDIR)/sdrkit_atap.so \
	$(LIBDIR)/sdrkit_biquad.so \
	$(LIBDIR)/sdrkit_constant.so \
	$(LIBDIR)/sdrkit_gain.so \
	$(LIBDIR)/sdrkit_iqbalancer.so \
	$(LIBDIR)/sdrkit_jack.so \
	$(LIBDIR)/sdrkit_mixer.so \
	$(LIBDIR)/sdrkit_mtap.so \
	$(LIBDIR)/sdrkit_oscillator.so

all:: $(ALL)
	cd $(LIBDIR) && make all

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

$(LIBDIR)/sdrkit_agc.so: sdrkit_agc.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_atap.so: sdrkit_atap.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_biquad.so: sdrkit_biquad.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_constant.so: sdrkit_constant.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_gain.so: sdrkit_gain.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_iqbalancer.so: sdrkit_iqbalancer.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_jack.so: sdrkit_jack.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_mixer.so: sdrkit_mixer.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_mtap.so: sdrkit_mtap.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_oscillator.so: sdrkit_oscillator.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

