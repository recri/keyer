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

# sdrtcl should actually be jacktcl
LIBSDRTCL=../lib/sdrtcl
ALSA=$(LIBSDRTCL)/alsa_device.so \
	$(LIBSDRTCL)/alsa_pcm.so \
	$(LIBSDRTCL)/alsa_rawmidi.so \
	$(LIBSDRTCL)/alsa_sequencer.so

KEYERS=$(LIBSDRTCL)/keyer_ascii.so \
	$(LIBSDRTCL)/keyer_debounce.so \
	$(LIBSDRTCL)/keyer_detime.so \
	$(LIBSDRTCL)/keyer_detone.so \
	$(LIBSDRTCL)/keyer_iambic_dttsp.so \
	$(LIBSDRTCL)/keyer_iambic_ad5dz.so \
	$(LIBSDRTCL)/keyer_iambic_nd7pa.so \
	$(LIBSDRTCL)/keyer_iambic_k1el.so \
	$(LIBSDRTCL)/keyer_iambic_vk6ph.so \
	$(LIBSDRTCL)/keyer_ptt.so \
	$(LIBSDRTCL)/keyer_ptt_mute.so \
	$(LIBSDRTCL)/keyer_tone.so

ALL=$(LIBSDRTCL)/agc.so \
	$(LIBSDRTCL)/audio_tap.so \
	$(LIBSDRTCL)/constant.so \
	$(LIBSDRTCL)/am_demod.so \
	$(LIBSDRTCL)/am_mod.so \
	$(LIBSDRTCL)/filter_biquad.so \
	$(LIBSDRTCL)/filter_complex_bandpass.so \
	$(LIBSDRTCL)/filter_complex_goertzel.so \
	$(LIBSDRTCL)/filter_fir.so \
	$(LIBSDRTCL)/filter_overlap_save.so \
	$(LIBSDRTCL)/filter_goertzel.so \
	$(LIBSDRTCL)/fftw.so \
	$(LIBSDRTCL)/gain.so \
	$(LIBSDRTCL)/iq_balance.so \
	$(LIBSDRTCL)/iq_correct.so \
	$(LIBSDRTCL)/iq_correct_train.so \
	$(LIBSDRTCL)/iq_delay.so \
	$(LIBSDRTCL)/iq_noise.so \
	$(LIBSDRTCL)/iq_rotation.so \
	$(LIBSDRTCL)/iq_swap.so \
	$(LIBSDRTCL)/jack_client.so \
	$(LIBSDRTCL)/jack_ctl.so \
	$(LIBSDRTCL)/jack_ringbuffer.so \
	$(LIBSDRTCL)/lo_mixer.so \
	$(LIBSDRTCL)/meter_tap.so \
	$(LIBSDRTCL)/midi.so \
	$(LIBSDRTCL)/midi_delay.so \
	$(LIBSDRTCL)/midi_insert.so \
	$(LIBSDRTCL)/midi_tap.so \
	$(LIBSDRTCL)/mixer.so \
	$(LIBSDRTCL)/fm_demod.so \
	$(LIBSDRTCL)/fm_mod.so \
	$(LIBSDRTCL)/noise.so \
	$(LIBSDRTCL)/oscillator.so \
	$(OSC_VARIANTS) \
	$(LIBSDRTCL)/sam_demod.so \
	$(LIBSDRTCL)/sample_delay.so \
	$(LIBSDRTCL)/spectrum_tap.so \
	$(LIBSDRTCL)/ssb_mod.so \
	$(LIBSDRTCL)/window.so \
	$(LIBSDRTCL)/window_polyphase.so \
	$(LIBSDRTCL)/hl_jack.so \
	$(LIBSDRTCL)/hl_udp_jack.so \
	$(LIBSDRTCL)/vector_dot.so \
	$(ALSA) \
	$(KEYERS) \
	$(LIBSDRTCL)/usb.so

OSC_VARIANTS=$(LIBSDRTCL)/oscillator_f.so \
	$(LIBSDRTCL)/oscillator_t.so \
	$(LIBSDRTCL)/oscillator_z.so \
	$(LIBSDRTCL)/oscillator_fd.so \
	$(LIBSDRTCL)/oscillator_td.so \
	$(LIBSDRTCL)/oscillator_zd.so

all:: $(ALL) libdir-all

clean:: libdir-clean
	rm -f *~ *.o

all-clean:: libdir-all-clean
	rm -f $(ALL)

libdir-all::
	cd $(LIBSDRTCL) && make all

libdir-clean::
	cd $(LIBSDRTCL) && make clean

libdir-all-clean::
	cd $(LIBSDRTCL) && make all-clean

$(LIBSDRTCL)/agc.so: agc.c framework.h ../dspmath/dspmath.h ../dspmath/agc.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBSDRTCL)/audio_tap.so: audio_tap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/constant.so: constant.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/am_demod.so: am_demod.c framework.h ../dspmath/demod_am.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/fm_demod.so: fm_demod.c framework.h ../dspmath/demod_fm.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/sam_demod.so: sam_demod.c framework.h ../dspmath/demod_sam.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_biquad.so: filter_biquad.c framework.h ../dspmath/filter_biquad.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_complex_bandpass.so: filter_complex_bandpass.c framework.h ../dspmath/filter_complex_bandpass.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_complex_goertzel.so: filter_complex_goertzel.c framework.h ../dspmath/midi.h ../dspmath/filter_complex_goertzel.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_fir.so: filter_FIR.c framework.h ../dspmath/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_goertzel.so: filter_goertzel.c framework.h ../dspmath/midi.h ../dspmath/filter_goertzel.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/filter_overlap_save.so: filter_overlap_save.c framework.h ../dspmath/filter_overlap_save.h ../dspmath/filter_FIR.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBSDRTCL)/fftw.so: fftw.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(FFTW3_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/gain.so: gain.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_balance.so: iq_balance.c framework.h ../dspmath/dspmath.h ../dspmath/iq_balance.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_correct.so: iq_correct.c framework.h ../dspmath/dspmath.h ../dspmath/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(FFTW3_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_correct_train.so: iq_correct_train.c framework.h ../dspmath/dspmath.h ../dspmath/iq_correct.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_delay.so: iq_delay.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_noise.so: iq_noise.c framework.h ../dspmath/dspmath.h ../dspmath/iq_noise.h ../dspmath/random_uniform.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_rotation.so: iq_rotation.c framework.h ../dspmath/dspmath.h ../dspmath/iq_rotation.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/iq_swap.so: iq_swap.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/jack_client.so: jack_client.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/jack_ctl.so: jack_ctl.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACKSERVER_LIBS) $(LIBS)

$(LIBSDRTCL)/jack_ringbuffer.so: jack_ringbuffer.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/lo_mixer.so: lo_mixer.c framework.h ../dspmath/lo_mixer.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/meter_tap.so: meter_tap.c framework.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/midi.so: midi.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/midi_delay.so: midi_delay.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/midi_insert.so: midi_insert.c framework.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/midi_tap.so: midi_tap.c framework.h ../dspmath/ring_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/mixer.so: mixer.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/am_mod.so: am_mod.c framework.h ../dspmath/mod_am.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/fm_mod.so: fm_mod.c framework.h ../dspmath/mod_fm.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/ssb_mod.so: ssb_mod.c framework.h ../dspmath/mod_ssb.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/noise.so: noise.c framework.h ../dspmath/dspmath.h ../dspmath/noise.h ../dspmath/random_uniform.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_f.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCF_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_t.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCT_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_z.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZ_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_fd.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCFD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_td.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCTD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/oscillator_zd.so: oscillator.c framework.h ../dspmath/dspmath.h ../dspmath/oscillator.h
	gcc -fPIC -shared -o $@ $(OSCZD_CFLAGS) $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/sample_delay.so: sample_delay.c framework.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/spectrum_tap.so: spectrum_tap.c framework.h ../dspmath/window.h ../dspmath/polyphase_fft.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $(JACK_CFLAGS) $< $(FFTW3_LIBS) $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/window.so: window.c framework.h ../dspmath/window.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/window_polyphase.so: window_polyphase.c framework.h ../dspmath/polyphase_fft.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/hl_jack.so: hl_jack.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/hl_udp_jack.so: hl_udp_jack.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/vector_dot.so: vector_dot.c framework.h ../dspmath/dspmath.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(LIBS)

$(LIBSDRTCL)/alsa_device.so: alsa_device.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBSDRTCL)/alsa_pcm.so: alsa_pcm.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBSDRTCL)/alsa_rawmidi.so: alsa_rawmidi.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBSDRTCL)/alsa_sequencer.so: alsa_sequencer.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(ALSA_CFLAGS) $< $(ALSA_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_ascii.so: keyer_ascii.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/morse_timing.h ../dspmath/morse_coding.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_debounce.so: keyer_debounce.cc framework.h ../dspmath/midi.h ../dspmath/debouncer.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_detime.so: keyer_detime.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/ring_buffer.h ../dspmath/detime.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_detone.so: keyer_detone.c framework.h ../dspmath/midi.h ../dspmath/filter_goertzel.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $<  $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_iambic_ad5dz.so: keyer_iambic_ad5dz.cc framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_ad5dz.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_iambic_nd7pa.so: keyer_iambic_nd7pa.cc framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_nd7pa.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_iambic_dttsp.so: keyer_iambic_dttsp.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_dttsp.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_iambic_k1el.so: keyer_iambic_k1el.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_k1el.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_iambic_vk6ph.so: keyer_iambic_vk6ph.cc framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h ../dspmath/iambic_vk6ph.h
	g++ -fPIC -shared -o $@ $(CPPFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_ptt.so: keyer_ptt.c framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_ptt_mute.so: keyer_ptt_mute.c framework.h ../dspmath/midi.h ../dspmath/midi_buffer.h
	gcc -fPIC -shared -o $@ $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/keyer_tone.so: keyer_tone.c framework.h keyer_options_def.h keyer_options_var.h ../dspmath/midi.h ../dspmath/keyed_tone.h\
	 ../dspmath/ramp.h ../dspmath/window.h
	gcc -fPIC -shared -o $@ $(OSC_CFLAGS) $(CFLAGS) $< $(JACK_LIBS) $(LIBS)

$(LIBSDRTCL)/usb.so: usb.c
	gcc -fPIC -shared -o $@ $(CFLAGS) $(LIBUSB_CFLAGS) $< $(LIBUSB_LIBS) $(LIBS)
