TCLVER=8.6
TCLINC=/usr/include/tcl$(TCLVER)
TCLLIB=/usr/lib/tcl$(TCLVER)
#TCLINC=/usr/local/include
#TCLLIB=/usr/local/lib

#CFLAGS=-std=c99 -g -O3 -I$(TCLINC) -DUSE_TCL_STUBS 
#CPPFLAGS= -g -O3 -I$(TCLINC) -DUSE_TCL_STUBS 
CFLAGS=-std=c99 -g -O3 -I$(TCLINC)
CPPFLAGS= -g -O3 -I$(TCLINC)

JACK_CFLAGS=$(shell pkg-config --cflags jack)
ALSA_CFLAGS=$(shell pkg-config --cflags alsa)
LIBUSB_CFLAGS=$(shell pkg-config --cflags libusb-1.0)
FFTW3_CFLAGS=$(shell pkg-config --cflags fftw3f)
OSC_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator\"

OSCF_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_INIT_NAME=Oscillator_f_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-f\" -DNO_GAIN
OSCT_CFLAGS=-DOSCILLATOR_T -DOSCILLATOR_INIT_NAME=Oscillator_t_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-t\" -DNO_GAIN
OSCZ_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_INIT_NAME=Oscillator_z_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-z\" -DNO_GAIN
OSCFD_CFLAGS=-DOSCILLATOR_F -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_fd_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-fd\" -DNO_GAIN
OSCTD_CFLAGS=-DOSCILLATOR_T -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_td_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-td\" -DNO_GAIN
OSCZD_CFLAGS=-DOSCILLATOR_Z -DOSCILLATOR_D -DOSCILLATOR_INIT_NAME=Oscillator_zd_Init -DOSCILLATOR_STRING_NAME=\"sdrtcl::oscillator-zd\" -DNO_GAIN

FIR_BPF_C_CFLAGS=-DFILTER_BAND_PASS -DFILTER_COMPLEX
FIR_LPF_R_CFLAGS=-DFILTER_LOW_PASS -DFILTER_REAL

#LIBS=-L$(TCLLIB) -ltclstub$(TCLVER) -lm
LIBS=-L$(TCLLIB) -ltcl$(TCLVER) -lm
JACK_LIBS=$(shell pkg-config --libs jack)
JACKSERVER_LIBS=-ljackserver
ALSA_LIBS=$(shell pkg-config --libs alsa)
LIBUSB_LIBS=$(shell pkg-config --libs libusb-1.0)
FFTW3_LIBS=$(shell pkg-config --libs fftw3f)

LIBDIR=../lib/sdrtcl

ALSA=$(LIBDIR)/alsa_device.so \
	$(LIBDIR)/alsa_pcm.so \
	$(LIBDIR)/alsa_rawmidi.so \
	$(LIBDIR)/alsa_sequencer.so

KEYERS=$(LIBDIR)/keyer_ascii.so \
	$(LIBDIR)/keyer_debounce.so \
	$(LIBDIR)/keyer_detime.so \
	$(LIBDIR)/keyer_detone.so \
	$(LIBDIR)/keyer_iambic_dttsp.so \
	$(LIBDIR)/keyer_iambic_ad5dz.so \
	$(LIBDIR)/keyer_iambic_nd7pa.so \
	$(LIBDIR)/keyer_iambic_k1el.so \
	$(LIBDIR)/keyer_iambic_vk6ph.so \
	$(LIBDIR)/keyer_ptt.so \
	$(LIBDIR)/keyer_ptt_mute.so \
	$(LIBDIR)/keyer_tone.so

ALL=$(LIBDIR)/agc.so \
	$(LIBDIR)/audio_tap.so \
	$(LIBDIR)/constant.so \
	$(LIBDIR)/demod_am.so \
	$(LIBDIR)/demod_fm.so \
	$(LIBDIR)/demod_sam.so \
	$(LIBDIR)/filter_complex_bandpass.so \
	$(LIBDIR)/filter_biquad.so \
	$(LIBDIR)/filter_fir.so \
	$(LIBDIR)/filter_overlap_save.so \
	$(LIBDIR)/fftw.so \
	$(LIBDIR)/gain.so \
	$(LIBDIR)/iq_balance.so \
	$(LIBDIR)/iq_correct.so \
	$(LIBDIR)/iq_correct_train.so \
	$(LIBDIR)/iq_delay.so \
	$(LIBDIR)/iq_noise.so \
	$(LIBDIR)/iq_rotation.so \
	$(LIBDIR)/iq_swap.so \
	$(LIBDIR)/jack_client.so \
	$(LIBDIR)/jack_ctl.so \
	$(LIBDIR)/jack_ringbuffer.so \
	$(LIBDIR)/lo_mixer.so \
	$(LIBDIR)/meter_tap.so \
	$(LIBDIR)/midi.so \
	$(LIBDIR)/midi_delay.so \
	$(LIBDIR)/midi_insert.so \
	$(LIBDIR)/midi_tap.so \
	$(LIBDIR)/mixer.so \
	$(LIBDIR)/mod_am.so \
	$(LIBDIR)/mod_fm.so \
	$(LIBDIR)/mod_ssb.so \
	$(LIBDIR)/noise.so \
	$(LIBDIR)/oscillator.so \
	$(OSC_VARIANTS) \
	$(LIBDIR)/spectrum_tap.so \
	$(LIBDIR)/window.so \
	$(LIBDIR)/window_polyphase.so \
	$(LIBDIR)/hl_jack.so \
	$(LIBDIR)/hl_udp_jack.so \
	$(ALSA) \
	$(KEYERS) \
	$(LIBDIR)/usb.so

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

$(LIBDIR)/agc.so: agc.c framework.h ../dspmath/dspmath.h ../dspmath/agc.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/audio_tap.so: audio_tap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/constant.so: constant.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_am.so: demod_am.c framework.h ../dspmath/demod_am.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_fm.so: demod_fm.c framework.h ../dspmath/demod_fm.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/demod_sam.so: demod_sam.c framework.h ../dspmath/demod_sam.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_complex_bandpass.so: filter_complex_bandpass.c framework.h ../dspmath/filter_complex_bandpass.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_biquad.so: filter_biquad.c framework.h ../dspmath/filter_biquad.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_fir.so: filter_FIR.c framework.h ../dspmath/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/filter_overlap_save.so: filter_overlap_save.c framework.h ../dspmath/filter_overlap_save.h ../dspmath/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/fftw.so: fftw.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/gain.so: gain.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_balance.so: iq_balance.c framework.h ../dspmath/dspmath.h ../dspmath/iq_balance.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_correct.so: iq_correct.c framework.h ../dspmath/dspmath.h ../dspmath/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBDIR)/iq_correct_train.so: iq_correct_train.c framework.h ../dspmath/dspmath.h ../dspmath/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_delay.so: iq_delay.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_noise.so: iq_noise.c framework.h ../dspmath/dspmath.h ../dspmath/iq_noise.h ../dspmath/random_uniform.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_rotation.so: iq_rotation.c framework.h ../dspmath/dspmath.h ../dspmath/iq_rotation.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/iq_swap.so: iq_swap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack_client.so: jack_client.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/jack_ctl.so: jack_ctl.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACKSERVER_LIBS) $(LIBS)

$(LIBDIR)/jack_ringbuffer.so: jack_ringbuffer.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/lo_mixer.so: lo_mixer.c framework.h ../dspmath/lo_mixer.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/meter_tap.so: meter_tap.c framework.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi.so: midi.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_delay.so: midi_delay.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_insert.so: midi_insert.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/midi_tap.so: midi_tap.c framework.h ../dspmath/ring_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mixer.so: mixer.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mod_am.so: mod_am.c framework.h ../dspmath/mod_am.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mod_fm.so: mod_fm.c framework.h ../dspmath/mod_fm.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/mod_ssb.so: mod_ssb.c framework.h ../dspmath/mod_ssb.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/noise.so: noise.c framework.h ../dspmath/dspmath.h ../dspmath/noise.h ../dspmath/random_uniform.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_f.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCF_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_t.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCT_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_z.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZ_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_fd.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCFD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_td.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCTD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/oscillator_zd.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/spectrum_tap.so: spectrum_tap.c framework.h ../dspmath/window.h ../dspmath/polyphase_fft.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBDIR)/window.so: window.c framework.h ../dspmath/window.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/window_polyphase.so: window_polyphase.c framework.h ../dspmath/polyphase_fft.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/hl_jack.so: hl_jack.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/hl_udp_jack.so: hl_udp_jack.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/alsa_device.so: alsa_device.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBDIR)/alsa_pcm.so: alsa_pcm.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBDIR)/alsa_rawmidi.so: alsa_rawmidi.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBDIR)/alsa_sequencer.so: alsa_sequencer.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBDIR)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/morse_timing.h ../dspmath/morse_coding.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_debounce.so: keyer_debounce.cc framework.h ../dspmath/midi.h ../dspmath/debouncer.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/ring_buffer.h ../dspmath/detime.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_detone.so: keyer_detone.c framework.h ../dspmath/midi.h ../dspmath/filter_goertzel.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_ad5dz.so: keyer_iambic_ad5dz.cc framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_ad5dz.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_nd7pa.so: keyer_iambic_nd7pa.cc framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_nd7pa.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_dttsp.so: keyer_iambic_dttsp.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_dttsp.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_k1el.so: keyer_iambic_k1el.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_k1el.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_iambic_vk6ph.so: keyer_iambic_vk6ph.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_vk6ph.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ptt.so: keyer_ptt.c framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_ptt_mute.so: keyer_ptt_mute.c framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/keyed_tone.h\
	 ../dspmath/ramp.h ../dspmath/window.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBDIR)/usb.so: usb.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(LIBUSB_CFLAGS) $< $(LIBUSB_LIBS) $(LIBS)
