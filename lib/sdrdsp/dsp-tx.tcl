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

package provide sdrdsp::dsp-tx 1.0.0

package require sdrctl::control

namespace eval sdrdsp {}

proc sdrdsp::tx {name args} {
    set seq {sdrdsp::tx-af sdrdsp::tx-if sdrdsp::tx-rf}
    set fopt [list -sequence $seq]
    return [sdrctl::control $name -type dsp -suffix tx -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}

proc sdrdsp::tx-af {name args} {
    # a lot of this is voice specific
    # CW only has a keyed oscillator feeding into the LO mixer
    # hw-softrock-dg8saq should have an option to poll keystate and insert as midi
    # hw-softrock-dg8saq should by default convert midi control to dg8saq, both directions
    array set fopt {
	-sequence sdrdsp::comp-gain
	-require sdrdsp::comp-gain
    }
    # lappend fopt(-sequence) sdrdsp::comp-real sdrdsp::comp-waveshape
    # lappend req sdrdsp::comp-real sdrdsp::comp-waveshape
    lappend fopt(-sequence) sdrdsp::comp-meter-waveshape
    lappend fopt(-require) sdrdsp::comp-meter
    # lappend fopt(-sequence) sdrdsp::comp-dc-block sdrdsp::comp-tx-squelch sdrdsp::comp-grapic-eq
    # lappend fopt(-require) sdrdsp::comp-dc-block sdrdsp::comp-tx-squelch sdrdsp::comp-grapic-eq
    lappend fopt(-sequence) sdrdsp::comp-meter-graphic-eq sdrdsp::comp-leveler sdrdsp::comp-meter-leveler
    lappend fopt(-require) sdrdsp::comp-meter sdrdsp::comp-leveler
    # lappend fopt(-sequence) sdrdsp::comp-speech-processor
    # lappend fopt(-require) sdrdsp::comp-speech-processor
    lappend fopt(-sequence) sdrdsp::comp-meter-speech-processor sdrdsp::comp-modul
    lappend fopt(-require) sdrdsp::comp-meter sdrdsp::comp-modul
    return [sdrctl::control $name -type dsp -suffix af -factory sdrdsp::dsp-sequence -factory-options [array get fopt] {*}$args]
}

proc sdrdsp::tx-if {name args} {
    array set fopt {
	-sequence sdrdsp::comp-filter-overlap-save
	-require sdrdsp::comp-filter-overlap-save
    }
    # lappend seq sdrdsp::comp-compand
    # lappend fopt(-require) sdrdsp::comp-compand
    lappend fopt(-sequence) sdrdsp::comp-meter-compand sdrdsp::comp-spectrum-tx sdrdsp::comp-lo-mixer
    lappend fopt(-require) sdrdsp::comp-meter sdrdsp::comp-spectrum sdrdsp::comp-lo-mixer
    return [sdrctl::control $name -type dsp -suffix if -factory sdrdsp::dsp-sequence -factory-options [array get fopt] {*}$args]
}

proc sdrdsp::tx-rf {name args} {
    array set fopt {
	-sequence {sdrdsp::comp-iq-balance sdrdsp::comp-gain sdrdsp::comp-meter-power}
	-require {sdrdsp::comp-iq-balance sdrdsp::comp-gain sdrdsp::comp-meter}
    }
    return [sdrctl::control $name -type dsp -suffix rf -factory sdrdsp::dsp-sequence -factory-options [array get fopt] {*}$args]
}

proc sdrdsp::tx-spectrum {name args} {
    package require sdrdsp::comp-spectrum-tap
    return [sdrdsp::comp-spectrum-tap $name -prefix tx {*}$args]
}

proc sdrdsp::tx-meter {name args} {
    package require sdrdsp::comp-meter-tap
    return [sdrdsp::comp-meter-tap $name -prefix tx {*}$args]
}
