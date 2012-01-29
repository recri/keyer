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
package provide sdrkit::options 1.0.0

namespace eval ::sdrkit {}
namespace eval ::sdrkit::options {
    
    array set modules {
	agc {sdrkit::agc norm}
	audio_tap {sdrkit::audio-tap atap}
	constant {sdrkit::constant norm}
	demod_am {sdrkit::demod-am norm}
	demod_fm {sdrkit::demod-fm norm}
	demod_sam {sdrkit::demod-sam norm}
	fftw {sdrkit::fftw no-jack}
	filter_FIR_band_pass_complex {sdrkit::filter-FIR-band-pass-complex needs-window}
	filter_FIR_low_pass_real {sdrkit::filter-FIR-low-pass-real needs-window}
	filter_biquad {sdrkit::filter-biquad norm}
	gain {sdrkit::gain norm}
	iq_balance {sdrkit::iq-balance norm}
	iq_correct {sdrkit::iq-correct norm}
	iq_noise {sdrkit::iq-noise norm}
	iq_swap {sdrkit::iq-swap norm}
	jack_client {sdrkit::jack-client norm}
	keyer_ascii {keyer::ascii norm}
	keyer_debounce {keyer::debounce norm}
	keyer_detime {keyer::detime norm}
	keyer_detone {keyer::detone norm}
	keyer_dttsp_iambic {keyer::dttsp-iambic norm}
	keyer_iambic {keyer::iambic norm}
	keyer_ptt {keyer::ptt norm}
	keyer_ptt_mute {keyer::ptt-mute norm}
	keyer_tone {keyer::tone norm}
	lo_mixer {sdrkit::lo-mixer norm}
	midi_insert {sdrkit::midi-insert norm}
	midi_tap {sdrkit::midi-tap norm}
	mixer {sdrkit::mixer norm}
	mono_to_iq {sdrkit::mono-to-iq norm}
	noise {sdrkit::noise norm}
	oscillator {sdrkit::oscillator norm}
	oscillator_f {sdrkit::oscillator-f norm}
	oscillator_fd {sdrkit::oscillator-fd norm}
	oscillator_t {sdrkit::oscillator-t norm}
	oscillator_td {sdrkit::oscillator-td norm}
	oscillator_z {sdrkit::oscillator-z norm}
	oscillator_zd {sdrkit::oscillator-zd norm}
	window {sdrkit::window no-jack}
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
	Tap {}
	Verbose {}
	Window {}
	Words {}
    }
}

proc ::sdrkit-module-has-info {module} {
    return [info exists ::sdrkit::options::modules($module)]
}
proc ::sdrkit-module-factory {module} {
    return [lindex $::sdrkit::options::modules($module) 0]
}
proc ::sdrkit-module-type {module} {
    return [lindex $::sdrkit::options::modules($module) 1]
}
proc ::sdrkit-option-note-configure {factory configure} {
    lassign $configure opt dbname clname defval curval
}
proc ::sdrkit-option-has-info {opt} {
    return [info exists ::sdrkit::options::options($opt)]
}
proc ::sdrkit-option-mark-seen {opt} {
    lappend ::sdrkit::options::options($opt) mark seen
}
proc ::sdrkit-dbname-has-info {dbname} {
    return [info exists ::sdrkit::options::dbnames($dbname)]
}
proc ::sdrkit-dbname-mark-seen {dbname} {
    lappend ::sdrkit::options::dbnames($dbname) mark seen
}
proc ::sdrkit-clname-has-info {clname} {
    return [info exists ::sdrkit::options::clnames($clname)]
}
proc ::sdrkit-clname-mark-seen {clname} {
    lappend ::sdrkit::options::clnames($clname) mark seen
}
proc ::sdrkit-get-props {factory opt dbname clname} {
    return $::sdrkit::options::options($opt)
}

