CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
LIBS=-ltclstub8.5

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
FFTW3_CFLAGS=$(shell pkg-config --cflags fftw3f)
OSC_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_INIT_NAME=Oscillator_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator\"
OSCF_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_INIT_NAME=Oscillatorf_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillatorf\"
OSCT_CFLAGS=-DOSCILLATOR_T -DOSCILLATOR_INIT_NAME=Oscillatort_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillatort\"
OSCZ_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_INIT_NAME=Oscillatorz_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillatorz\"

JACK_LIBS=$(shell pkg-config --libs jack)
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)
FFTW3_LIBS=$(shell pkg-config --libs fftw3f)

LIBDIR=../lib/sdrkit

KEYERS=$(LIBDIR)/keyer_ascii.so \
	$(LIBDIR)/keyer_debounce.so \
	$(LIBDIR)/keyer_detime.so \
	$(LIBDIR)/keyer_dttsp_iambic.so \
	$(LIBDIR)/keyer_iambic.so \
	$(LIBDIR)/keyer_ptt.so \
	$(LIBDIR)/keyer_ptt_mute.so \
	$(LIBDIR)/keyer_tone.so

ALL=$(LIBDIR)/agc.so \
	$(LIBDIR)/atap.so \
	$(LIBDIR)/audio_tap.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/filter_biquad.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/iq_correct.so \
	$(LIBDIR)/iq_noise.so \
	$(LIBDIR)/iq_swap.so \
	$(LIBDIR)/jack_client.so \
	$(LIBDIR)/lo_mixer.so \
	$(LIBDIR)/midi_insert.so \
	$(LIBDIR)/mixer.so \
	$(LIBDIR)/mono_to_iq.so \
	$(LIBDIR)/mtap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(LIBDIR)/oscillatorf.so \
	$(LIBDIR)/oscillatort.so \
	$(LIBDIR)/oscillatorz.so \
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

$(LIBDIR)/agc.so: agc.c framework.h ../sdrkit/dmath.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/atap.so: atap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/audio_tap.so: audio_tap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_biquad.so: filter_biquad.c framework.h ../sdrkit/filter_biquad.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/constant.so: constant.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/fftw.so: fftw.c framework.h ../sdrkit/window.h ../sdrkit/dmath.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h ../sdrkit/dmath.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_balance.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_correct.so: iq_correct.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_correct.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_noise.so: iq_noise.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_noise.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_swap.so: iq_swap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack_client.so: jack_client.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/lo_mixer.so: lo_mixer.c framework.h ../sdrkit/lo_mixer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_insert.so: midi_insert.c framework.h ../sdrkit/midi_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mixer.so: mixer.c framework.h ../sdrkit/dmath.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mono_to_iq.so: mono_to_iq.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mtap.so: mtap.c framework.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../sdrkit/dmath.h ../sdrkit/noise.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillatorf.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSCF_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillatort.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSCT_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillatorz.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSCZ_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/morse_timing.h ../sdrkit/morse_coding.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_debounce.so: keyer_debounce.cc framework.h ../sdrkit/midi.h ../sdrkit/Debounce.h
	@mkdir -p $(LIBDIR)
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $<  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/ring_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_iambic.so: keyer_iambic.cc framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/Iambic.h
	@mkdir -p $(LIBDIR)
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ptt.so: keyer_ptt.c framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_ptt_mute.so: keyer_ptt_mute.c framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/keyed_tone.h
	@mkdir -p $(LIBDIR)
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

$(LIBDIR)/keyer_dttsp_iambic.so: keyer_dttsp_iambic.cc framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/dttsp_iambic.h
	@mkdir -p $(LIBDIR)
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS) -lm

