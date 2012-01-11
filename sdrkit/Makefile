CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.5

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
FFTW3_CFLAGS=$(shell pkg-config --cflags fftw3f)
JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)
FFTW3_LIBS=$(shell pkg-config --libs fftw3f)

LIBDIR=../lib/sdrkit

ALL=$(LIBDIR)/sdrkit_agc.so \
	$(LIBDIR)/atap.so \
	$(LIBDIR)/biquad.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/sdrkit_fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/sdrkit_jack.so \
	$(LIBDIR)/sdrkit_lo_mixer.so \
	$(LIBDIR)/sdrkit_mixer.so \
	$(LIBDIR)/sdrkit_mtap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/sdrkit_oscillator.so

all:: $(ALL)
	cd $(LIBDIR) && make all

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

$(LIBDIR)/sdrkit_agc.so: sdrkit_agc.c sdrkit.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/atap.so: atap.c framework.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/biquad.so: biquad.c framework.h ../dspkit/biquad_filter.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/constant.so: constant.c framework.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_fftw.so: sdrkit_fftw.c sdrkit.h ../dspkit/window.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_jack.so: sdrkit_jack.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_lo_mixer.so: sdrkit_lo_mixer.c sdrkit.h ../dspkit/lo_mixer.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_mixer.so: sdrkit_mixer.c sdrkit.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_mtap.so: sdrkit_mtap.c sdrkit.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../dspkit/avoid_denormals.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/sdrkit_oscillator.so: sdrkit_oscillator.c sdrkit.h sdrkit_math.h ../dspkit/oscillator.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

