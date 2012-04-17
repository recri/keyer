CFLAGS=-std=c99 -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 
CPPFLAGS= -g -O3 -I/usr/include/tcl8.5 -DUSE_TCL_STUBS 

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
FFTW3_CFLAGS=$(shell pkg-config --cflags fftw3f)

OSC_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator\"

OSCF_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_INIT_NAME=Oscillator_f_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-f\" -DNO_GAIN
OSCT_CFLAGS=-DOSCILLATOR_T -DOSCILLATOR_INIT_NAME=Oscillator_t_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-t\" -DNO_GAIN
OSCZ_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_INIT_NAME=Oscillator_z_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-z\" -DNO_GAIN
OSCFD_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_fd_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-fd\" -DNO_GAIN
OSCTD_CFLAGS=-DOSCILLATOR_T -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_td_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-td\" -DNO_GAIN
OSCZD_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_zd_Init -DOSCILLATOR_STRING_NAME=\"sdrkit::oscillator-zd\" -DNO_GAIN

FIR_BPF_C_CFLAGS=-DFILTER_BAND_PASS -DFILTER_COMPLEX
FIR_LPF_R_CFLAGS=-DFILTER_LOW_PASS -DFILTER_REAL

LIBS=-ltclstub8.5 -lm
JACK_LIBS=$(shell pkg-config --libs jack)
JACKSERVER_LIBS=-ljackserver
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)
FFTW3_LIBS=$(shell pkg-config --libs fftw3f)

LIBDIR=../lib/sdrkit

KEYERS=$(LIBDIR)/keyer_ascii.so \
	$(LIBDIR)/keyer_debounce.so \
	$(LIBDIR)/keyer_detime.so \
	$(LIBDIR)/keyer_detone.so \
	$(LIBDIR)/keyer_iambic_dttsp.so \
	$(LIBDIR)/keyer_iambic_ad5dz.so \
	$(LIBDIR)/keyer_iambic_nd7pa.so \
	$(LIBDIR)/keyer_ptt.so \
	$(LIBDIR)/keyer_ptt_mute.so \
	$(LIBDIR)/keyer_tone.so

ALL=$(LIBDIR)/agc.so \
	$(LIBDIR)/audio_tap.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/demod_am.so \
	$(LIBDIR)/demod_fm.so \
	$(LIBDIR)/demod_sam.so \
	$(LIBDIR)/demod_block.so \
	$(LIBDIR)/filter_complex_bandpass.so \
	$(LIBDIR)/filter_biquad.so \
	$(LIBDIR)/filter_fir.so \
	$(LIBDIR)/filter_overlap_save.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/input_block.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/iq_correct.so \
	$(LIBDIR)/iq_delay.so \
	$(LIBDIR)/iq_noise.so \
	$(LIBDIR)/iq_rotation.so \
	$(LIBDIR)/iq_swap.so \
	$(LIBDIR)/jack_client.so \
	$(LIBDIR)/jack_ctl.so \
	$(LIBDIR)/lo_mixer.so \
	$(LIBDIR)/midi_insert.so \
	$(LIBDIR)/mixer.so \
	$(LIBDIR)/midi_tap.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(LIBDIR)/window.so \
	$(LIBDIR)/window_polyphase.so \
	$(KEYERS)

OSC_VARIANTS=$(LIBDIR)/oscillator_f.so \
	$(LIBDIR)/oscillator_t.so \
	$(LIBDIR)/oscillator_z.so \
	$(LIBDIR)/oscillator_fd.so \
	$(LIBDIR)/oscillator_td.so \
	$(LIBDIR)/oscillator_zd.so

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

$(LIBDIR)/agc.so: agc.c framework.h ../sdrkit/dmath.h ../sdrkit/agc.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/audio_tap.so: audio_tap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/constant.so: constant.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_am.so: demod_am.c framework.h ../sdrkit/demod_am.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_fm.so: demod_fm.c framework.h ../sdrkit/demod_fm.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_sam.so: demod_sam.c framework.h ../sdrkit/demod_sam.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_block.so: demod_block.c framework.h ../sdrkit/demod_am.h  ../sdrkit/demod_fm.h ../sdrkit/demod_sam.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_complex_bandpass.so: filter_complex_bandpass.c framework.h ../sdrkit/filter_complex_bandpass.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_biquad.so: filter_biquad.c framework.h ../sdrkit/filter_biquad.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_fir.so: filter_FIR.c framework.h ../sdrkit/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_overlap_save.so: filter_overlap_save.c framework.h ../sdrkit/filter_overlap_save.h ../sdrkit/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/fftw.so: fftw.c framework.h ../sdrkit/dmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h ../sdrkit/dmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/input_block.so: input_block.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_balance.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_correct.so: iq_correct.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_delay.so: iq_delay.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_noise.so: iq_noise.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_noise.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_rotation.so: iq_rotation.c framework.h ../sdrkit/dmath.h ../sdrkit/iq_rotation.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_swap.so: iq_swap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack_client.so: jack_client.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack_ctl.so: jack_ctl.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACKSERVER_LIBS) $(LIBS)

$(LIBDIR)/lo_mixer.so: lo_mixer.c framework.h ../sdrkit/lo_mixer.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_insert.so: midi_insert.c framework.h ../sdrkit/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mixer.so: mixer.c framework.h ../sdrkit/dmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_tap.so: midi_tap.c framework.h ../sdrkit/ring_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../sdrkit/dmath.h ../sdrkit/noise.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_f.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCF_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_t.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCT_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_z.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZ_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_fd.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCFD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_td.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCTD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_zd.so: oscillator.c framework.h ../sdrkit/dmath.h ../sdrkit/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/window.so: window.c framework.h ../sdrkit/window.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/window_polyphase.so: window_polyphase.c framework.h ../sdrkit/polyphase_fft.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/morse_timing.h ../sdrkit/morse_coding.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_debounce.so: keyer_debounce.cc framework.h ../sdrkit/midi.h ../sdrkit/debouncer.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/ring_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_detone.so: keyer_detone.c framework.h ../sdrkit/midi.h ../sdrkit/filter_goertzel.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_ad5dz.so: keyer_iambic_ad5dz.cc framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/iambic_ad5dz.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_nd7pa.so: keyer_iambic_nd7pa.cc framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/iambic_nd7pa.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_dttsp.so: keyer_iambic_dttsp.cc framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h ../sdrkit/iambic_dttsp.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ptt.so: keyer_ptt.c framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ptt_mute.so: keyer_ptt_mute.c framework.h ../sdrkit/midi.h ../sdrkit/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../sdrkit/midi.h ../sdrkit/keyed_tone.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

