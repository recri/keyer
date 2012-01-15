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
	$(LIBDIR)/audio_tap.so \
	$(LIBDIR)/biquad.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/iq_swap.so \
	$(LIBDIR)/jack.so \
	$(LIBDIR)/lo_mixer.so \
	$(LIBDIR)/midi_insert.so \
	$(LIBDIR)/mixer.so \
	$(LIBDIR)/mono_to_iq.so \
	$(LIBDIR)/mtap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(KEYERS)

all:: $(ALL) libdir-all

clean:: libdir-clean
	rm -f *~ *.o

all-clean:: libdir-all-clean
	rm -f $(ALL)

libdir-all::
	cd $(LIBDIR) && make all

libdir-clean::
	cd $(LIBDIR) && make clean

libdir-all-clean::
	cd $(LIBDIR) && make all-clean

$(LIBDIR)/agc.so: agc.c framework.h ../sdrkit/kit_math.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/atap.so: atap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/audio_tap.so: audio_tap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/biquad.so: biquad.c framework.h ../sdrkit/biquad_filter.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/constant.so: constant.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/fftw.so: fftw.c framework.h ../sdrkit/window.h ../sdrkit/kit_math.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h ../sdrkit/kit_math.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h ../sdrkit/kit_math.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_swap.so: iq_swap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack.so: jack.c
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/lo_mixer.so: lo_mixer.c framework.h ../sdrkit/lo_mixer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_insert.so: midi_insert.c framework.h ../sdrkit/midi_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mixer.so: mixer.c framework.h ../sdrkit/kit_math.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mono_to_iq.so: mono_to_iq.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mtap.so: mtap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../sdrkit/avoid_denormals.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator.so: oscillator.c framework.h ../sdrkit/kit_math.h ../sdrkit/oscillator.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/keyed_tone.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) keyer_tone.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/ring_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) keyer_detime.c  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/morse_timing.h ../sdrkit/morse_coding.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) keyer_ascii.c $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h
	@mkdir -p $(LIBDIR)
	g++ -fPIC -shared -o $@ $(CPPFLAGS) keyer_iambic.cc $(JACK_LIBS) $(LIBS) -lm

