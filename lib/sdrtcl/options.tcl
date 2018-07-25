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

package require snit

namespace eval ::sdrtcl {
    set options [dict create \
		 package {
		     sdrtcl::agc {type norm}
		     sdrtcl::audio-tap {type atap}
		     sdrtcl::constant {type norm}
		     sdrtcl::demod-am {type norm}
		     sdrtcl::demod-fm {type norm}
		     sdrtcl::demod-sam {type norm}
		     sdrtcl::fftw {type no-jack}
		     sdrtcl::filter-fir {type filter}
		     sdrtcl::filter-biquad {type norm}
		     sdrtcl::gain {type norm}
		     sdrtcl::iq-balance {type norm}
		     sdrtcl::iq-correct {type norm}
		     sdrtcl::iq-delay {type norm}
		     sdrtcl::iq-noise {type norm}
		     sdrtcl::iq-rotation {type norm}
		     sdrtcl::iq-swap {type norm}
		     sdrtcl::jack-client {type norm}
		     sdrtcl::keyer-ascii {type norm}
		     sdrtcl::keyer-debounce {type norm}
		     sdrtcl::keyer-detime {type norm}
		     sdrtcl::keyer-detone {type norm}
		     sdrtcl::keyer-dttsp-iambic {type norm}
		     sdrtcl::keyer-ad5dz-iambic {type norm}
		     sdrtcl::keyer-nd7pa-iambic {type norm}
		     sdrtcl::keyer-ptt {type norm}
		     sdrtcl::keyer-ptt-mute {type norm}
		     sdrtcl::keyer-tone {type norm}
		     sdrtcl::lo-mixer {type norm}
		     sdrtcl::midi-insert {type norm}
		     sdrtcl::midi-tap {type norm}
		     sdrtcl::mixer {type norm}
		     sdrtcl::mono-to-iq {type norm}
		     sdrtcl::noise {type norm}
		     sdrtcl::oscillator {type norm}
		     sdrtcl::window {type window}
		     sdrtcl::window-polyphase {type window}
		 } option {
		     -a1 {type float}
		     -a2 {type float}
		     -alsp {type integer values {0 1}}
		     -awsp {type integer values {0 1}}
		     -b0 {type float}
		     -b1 {type float}
		     -b2 {type float}
		     -bandwidth {type float range {100 10000}}
		     -chan {type integerrange {1 16}}
		     -client {create-only 1 type string}
		     -dah {range {2.5 3.5} type float}
		     -delay {range {0 5000} type integer}
		     -dict {type dict}
		     -direction {values {-1 1} type integer}
		     -dit {range {0.5 1.5} type float}
		     -fall {range {0 15} type float unit ms}
		     -freq {range {-10000 10000} type float}
		     -gain {range {0 -160} type float unit dB}
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
		     -window {type enum values {}}
		     -word {type enum values {50 60}}
		     -wpm {range {5 50} type float step 0.5 format {%.1f}}
		 } dbname {
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
		 } clname {
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
		 } \
		    ]
}

snit::type sdrtcl::options {
    method packages {} { return [dict keys $::sdrtcl::options package] }
    method commands {} { return [dict keys $::sdrtcl::options command] }
    method options {} { return [dict keys $::sdrtcl::options option] }
    method dbnames {} { return [dict keys $::sdrtcl::options dbname] }
    method clnames {} { return [dict keys $::sdrtcl::options clname] }
    method {package exists} {package} { return [dict exists $::sdrtcl::options package $package] }
    method {option exists} {option} { return [dict exists $::sdrtcl::options option $option] }
    method {dbname exists} {dbname} { return [dict exists $::sdrtcl::options dbname $dbname] } 
    method {clname exists} {clname} { return [dict exists $::sdrtcl::options clname $clname] } 
    method {package type} {package} { return [dict get $::sdrtcl::options package $package type] }
    method {option type} {option} { return [dict get $::sdrtcl::options option $option type] }
    method {dbname type} {dbname} { return [dict get $::sdrtcl::options dbname $dbname type] } 
    method {clname type} {clname} { return [dict get $::sdrtcl::options clname $clname type] } 
}

