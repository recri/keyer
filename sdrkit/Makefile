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
	$(LIBDIR)/keyer_detime.so \
	$(LIBDIR)/keyer_iambic.so \
	$(LIBDIR)/keyer_tone.so

ALL=$(LIBDIR)/agc.so \
	$(LIBDIR)/atap.so \
	$(LIBDIR)/biquad.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/iq_swap.so \
	$(LIBDIR)/jack.so \
	$(LIBDIR)/lo_mixer.so \
	$(LIBDIR)/mixer.so \
	$(LIBDIR)/mono_to_iq.so \
	$(LIBDIR)/mtap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(KEYERS)

all:: $(ALL)
	cd $(LIBDIR) && make all

all-clean:: clean
	rm -f $(ALL)

clean::
	rm -f *~ *.o

$(LIBDIR)/agc.so: agc.c framework.h sdrkit_math.h
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

$(LIBDIR)/fftw.so: fftw.c framework.h ../dspkit/window.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_swap.so: iq_swap.c framework.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack.so: jack.c
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/lo_mixer.so: lo_mixer.c framework.h ../dspkit/lo_mixer.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mixer.so: mixer.c framework.h sdrkit_math.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mono_to_iq.so: mono_to_iq.c framework.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mtap.so: mtap.c framework.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../dspkit/avoid_denormals.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator.so: oscillator.c framework.h sdrkit_math.h ../dspkit/oscillator.h
	mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/keyed_tone.h
	mkdir -p $(LIBDIR)
	cc -o $@ -shared -fPIC $(CFLAGS) keyer_tone.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/ring_buffer.h
	mkdir -p $(LIBDIR)
	cc -o $@ $(CFLAGS) -shared -fPIC keyer_detime.c  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/midi_buffer.h ../dspkit/morse_timing.h ../dspkit/morse_coding.h
	mkdir -p $(LIBDIR)
	cc -o $@ $(CFLAGS) -shared -fPIC keyer_ascii.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h keyer_options_def.h keyer_options_var.h ../dspkit/midi.h ../dspkit/midi_buffer.h
	mkdir -p $(LIBDIR)
	g++ -o $@ $(CPPFLAGS) -shared -fPIC keyer_iambic.cc $(JACK_LIBS) $(LIBS) -lm

