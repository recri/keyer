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

#
# a control dial
#
package provide sdrkit::control-dial 1.0.0

package require snit
package require sdrtk::dialbook
package require sdrtk::readout-enum
package require sdrtk::readout-freq
package require sdrtk::readout-value
package require sdrutil::util

namespace eval sdrkit {}

snit::widgetadaptor sdrkit::control-dial {
    option -command {}

    # hmm, the actual set depends on mode
    # and whether you're running split

    option -agc-mode -default medium -configuremethod Configure
    option -mode -default CWU -configuremethod Configure
    option -freq -default 7050000 -configuremethod Configure
    option -tune-rate -default 50 -configuremethod Configure
    option -lo-freq -default 10000 -configuremethod Configure
    option -lo-tune-rate -default 50 -configuremethod Configure
    option -cw-freq -default 400 -configuremethod Configure
    option -bpf-width -default 200 -configuremethod Configure
    option -rx-af-gain -default 0 -configuremethod Configure
    option -rx-rf-gain -default 0 -configuremethod Configure

    option -sub-controls {
	freq freq {-text VFO -format {%.6f} -units MHz -step 50}
	tune-rate enum {-text {VFO Step} -values {{1 Hz} {5 Hz} {10 Hz} {25 Hz} {50 Hz} {100 Hz} {250 Hz} {500 Hz} {1 kHz} {2.5 kHz} {5 kHz} {10 kHz} {25 kHz}}} 
	lo-freq freq {-text LO -format {%.0f} -units Hz}
	lo-tune-rate enum {-text {LFO Step} -values {{1 Hz} {5 Hz} {10 Hz} {25 Hz} {50 Hz} {100 Hz} {250 Hz} {500 Hz} {1 kHz} {2.5 kHz} {5 kHz} {10 kHz} {25 kHz}}} 
	agc-mode enum {-text AGC -values {off long slow medium fast}}
	mode enum {-text Mode -values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}}
	cw-freq freq {-text {CW Tone} -format {%.0f} -units Hz}
	bpf-width freq {-text {BPF Width} -format {%.0f} -units Hz}
	rx-af-gain value {-text {RX AF Gain} -format {%.1f} -units dB -step 0.1}
	rx-rf-gain value {-text {RX RF Gain} -format {%.1f} -units dB -step 0.1}
    }
	
    variable data -array {
    }

    constructor {args} {
	installhull using sdrtk::dialbook
	$self configure {*}$args
	foreach {opt type opts} $options(-sub-controls) {
	    lappend opts -value $options(-$opt) -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
	    switch $type {
		enum { sdrtk::readout-enum $win.$opt {*}$opts }
		freq { sdrtk::readout-freq $win.$opt {*}$opts }
		value { sdrtk::readout-value $win.$opt {*}$opts }
		default { error "unanticipated type \"$type\"" }
	    }
	    $hull add $win.$opt -text [$win.$opt cget -text]
	}
    }

    method Constrain {opt val} { return $val }
    method OptionConfigure {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -tune-rate { $win.freq configure -step [sdrutil::hertz $val] }
	    -lo-tune-rate { $win.lo-freq configure -step [sdrutil::hertz $val] }
	}
    }
    method ControlConfigure {opt val} { if {$options(-command) ne {}} { {*}$options(-command) $opt $val } }

    method Configure {opt val} {
	set val [$self Constrain $opt $val]
	$self OptionConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self Constrain $opt $val]
	$self OptionConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
