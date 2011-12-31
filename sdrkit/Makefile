CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.5

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)

ALL=../lib/sdrkit_agc.so \
	../lib/sdrkit_atap.so \
	../lib/sdrkit_biquad.so \
	../lib/sdrkit_constant.so \
	../lib/sdrkit_gain.so \
	../lib/sdrkit_iqbalancer.so \
	../lib/sdrkit_jack.so \
	../lib/sdrkit_mixer.so \
	../lib/sdrkit_mtap.so \
	../lib/sdrkit_oscillator.so

all: $(ALL)

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

../lib/sdrkit_agc.so: sdrkit_agc.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_atap.so: sdrkit_atap.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_biquad.so: sdrkit_biquad.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_constant.so: sdrkit_constant.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_gain.so: sdrkit_gain.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_iqbalancer.so: sdrkit_iqbalancer.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_jack.so: sdrkit_jack.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_mixer.so: sdrkit_mixer.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_mtap.so: sdrkit_mtap.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

../lib/sdrkit_oscillator.so: sdrkit_oscillator.c sdrkit.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

