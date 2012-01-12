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

KEYERS=$(LIBDIR)/keyer_ascii.so \
	$(LIBDIR)/keyer_decode.so \
	$(LIBDIR)/keyer_iambic.so \
	$(LIBDIR)/keyer_tone.so

ALL=$(LIBDIR)/sdrkit_agc.so \
	$(LIBDIR)/atap.so \
	$(LIBDIR)/biquad.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/sdrkit_jack.so \
	$(LIBDIR)/sdrkit_lo_mixer.so \
	$(LIBDIR)/sdrkit_mixer.so \
	$(LIBDIR)/sdrkit_mtap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(KEYERS)

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

$(LIBDIR)/fftw.so: fftw.c sdrkit.h ../dspkit/window.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

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

$(LIBDIR)/oscillator.so: oscillator.c sdrkit.h sdrkit_math.h ../dspkit/oscillator.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/keyed_tone.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_tone.so -shared -fPIC -DAS_TCL $(CFLAGS) keyer_tone.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_decode.so: keyer_decode.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/ring_buffer.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_decode.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_decode.c  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/midi_buffer.h ../dspkit/morse_timing.h ../dspkit/morse_coding.h
	mkdir -p $(LIBDIR)
	cc -o $(LIBDIR)/keyer_ascii.so $(CFLAGS) -shared -fPIC -DAS_TCL keyer_ascii.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/midi_buffer.h
	mkdir -p $(LIBDIR)
	g++ -o $(LIBDIR)/keyer_iambic.so $(CPPFLAGS) -shared -fPIC -DAS_TCL keyer_iambic.cc $(JACK_LIBS) $(LIBS) -lm

