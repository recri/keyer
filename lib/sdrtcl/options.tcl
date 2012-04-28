# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 
package provide sdrtcl::options 1.0.0

namespace eval ::sdrkit {}
namespace eval ::sdrtcl::options {
    
    array set modules {
	agc {sdrtcl::agc norm}
	audio_tap {sdrtcl::audio-tap atap}
	constant {sdrtcl::constant norm}
	demod_am {sdrtcl::demod-am norm}
	demod_fm {sdrtcl::demod-fm norm}
	demod_sam {sdrtcl::demod-sam norm}
	fftw {sdrtcl::fftw no-jack}
	filter_fir {sdrtcl::filter-fir filter}
	filter_biquad {sdrtcl::filter-biquad norm}
	gain {sdrtcl::gain norm}
	iq_balance {sdrtcl::iq-balance norm}
	iq_correct {sdrtcl::iq-correct norm}
	iq_delay {sdrtcl::iq-delay norm}
	iq_noise {sdrtcl::iq-noise norm}
	iq_rotation {sdrtcl::iq-rotation norm}
	iq_swap {sdrtcl::iq-swap norm}
	jack_client {sdrtcl::jack-client norm}
	keyer_ascii {sdrtcl::keyer-ascii norm}
	keyer_debounce {sdrtcl::keyer-debounce norm}
	keyer_detime {sdrtcl::keyer-detime norm}
	keyer_detone {sdrtcl::keyer-detone norm}
	keyer_dttsp_iambic {sdrtcl::keyer-dttsp-iambic norm}
	keyer_ad5dz_iambic {sdrtcl::keyer-ad5dz-iambic norm}
	keyer_nd7pa_iambic {sdrtcl::keyer-nd7pa-iambic norm}
	keyer_ptt {sdrtcl::keyer-ptt norm}
	keyer_ptt_mute {sdrtcl::keyer-ptt-mute norm}
	keyer_tone {sdrtcl::keyer-tone norm}
	lo_mixer {sdrtcl::lo-mixer norm}
	midi_insert {sdrtcl::midi-insert norm}
	midi_tap {sdrtcl::midi-tap norm}
	mixer {sdrtcl::mixer norm}
	mono_to_iq {sdrtcl::mono-to-iq norm}
	noise {sdrtcl::noise norm}
	oscillator {sdrtcl::oscillator norm}
	oscillator_f {sdrtcl::oscillator-f norm}
	oscillator_fd {sdrtcl::oscillator-fd norm}
	oscillator_t {sdrtcl::oscillator-t norm}
	oscillator_td {sdrtcl::oscillator-td norm}
	oscillator_z {sdrtcl::oscillator-z norm}
	oscillator_zd {sdrtcl::oscillator-zd norm}
	window {sdrtcl::window window}
	window_polyphase {sdrtcl::window-polyphase window}
    }

    array set factories {
    }

    array set options {
	-a1 {type float}
	-a2 {type float}
	-alsp {values {0 1} type integer}
	-awsp {values {0 1} type integer}
	-b0 {type float}
	-b1 {type float}
	-b2 {type float}
	-bandwidth {type float range {100 10000}}
	-chan {range {1 16} type integer}
	-client {create-only 1 type string}
	-dah {range {2.5 3.5} type float}
	-delay {range {0 5000} type integer}
	-dict {type dict}
	-direction {values {-1 1} type integer}
	-fall {range {1 10} type float}
	-freq {range {-10000 10000} type float}
	-gain {range {0 -160} type float}
	-hang {range {0 10} type float}
	-ies {range {0.5 1.5} type float}
	-ils {range {2.5 3.5} type float}
	-imag {type float}
	-iws {range {6 8} type float}
	-level {range {0 -160} type float}
	-linear-gain {range {1e-6 1} type float}
	-mdit {values {0 1} type integer} 
	-mdah {values {0 1} type integer}
	-mide {values {0 1} type integer}
	-mode {values {A B} type string}
	-mu {range {0 1} type float}
	-note {range {0 127} type integer}
	-period {range {10 10000} type float}
	-planbits {type integer}
	-real {type float}
	-rise {range {1 10} type float}
	-seed {create-only 1 type integer range {1 2147483648}}
	-server {create-only 1 type string}
	-sine-phase {range {-1.0 1.0} type float}
	-size {range {1 10000} type integer}
	-steps {values {1 64} type integer}
	-swap {values {0 1} type integer}
	-verbose {range {0 100} type integer}
	-weight {range {25 75} type integer}
	-window {range {0 12} type integer}
	-word {range {50 60} type float}
	-wpm {range {5 50} type float}
    }

    array set dbnames {
	alsp {}
	awsp {}
	bandwidth {}
	channel {}
	client {}
	dah {}
	delay {}
	dict {}
	direction {}
	fall {}
	frequency {}
	gain {}
	hang {}
	ies {}
	ils {}
	imag {}
	iws {}
	level {}
	mdah {}
	mdit {}
	mide {}
	mode {}
	mu {}
	note {}
	period {}
	phase {}
	planbits {}
	real {}
	rise {}
	seed {}
	server {}
	size {}
	steps {}
	swap {}
	tap {}
	verbose {}
	weight {}
	window {}
	word {}
	wpm {}
    }

    array set clnames {
	AFBandwidth {}
	AFHertz {type float range {200.0 1600.0}}
	Bool {}
	BWHertz {}
	Channel {}
	Char {}
	Client {}
	Decibel {}
	Decibels {}
	Delay {}
	Direction {}
	Dits {}
	Gain {}
	Hang {}
	Hertz {}
	Imag {}
	Memo {}
	Mode {}
	Morse {}
	Mu {}
	Note {}
	Period {}
	Phase {}
	Planbits {}
	Ramp {}
	Real {}
	Samples {}
	Seed {}
	Server {}
	Steps {}
	Swap {}
	Tap {}
	Verbose {}
	Window {}
	Words {}
    }
}

proc ::sdrkit-module-has-info {module} {
    return [info exists ::sdrtcl::options::modules($module)]
}
proc ::sdrkit-module-factory {module} {
    return [lindex $::sdrtcl::options::modules($module) 0]
}
proc ::sdrkit-module-type {module} {
    return [lindex $::sdrtcl::options::modules($module) 1]
}
proc ::sdrkit-option-note-configure {factory configure} {
    lassign $configure opt dbname clname defval curval
}
proc ::sdrkit-option-has-info {opt} {
    return [info exists ::sdrtcl::options::options($opt)]
}
proc ::sdrkit-option-mark-seen {opt} {
    lappend ::sdrtcl::options::options($opt) mark seen
}
proc ::sdrkit-dbname-has-info {dbname} {
    return [info exists ::sdrtcl::options::dbnames($dbname)]
}
proc ::sdrkit-dbname-mark-seen {dbname} {
    lappend ::sdrtcl::options::dbnames($dbname) mark seen
}
proc ::sdrkit-clname-has-info {clname} {
    return [info exists ::sdrtcl::options::clnames($clname)]
}
proc ::sdrkit-clname-mark-seen {clname} {
    lappend ::sdrtcl::options::clnames($clname) mark seen
}
proc ::sdrkit-get-props {factory opt dbname clname} {
    return $::sdrtcl::options::options($opt)
}

