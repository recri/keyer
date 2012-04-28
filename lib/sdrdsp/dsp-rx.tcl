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

package provide sdrdsp::dsp-rx 1.0.0

package require sdrctl::control
package require sdrdsp::dsp-sequence

namespace eval sdrdsp {}

proc sdrdsp::rx {name args} {
    set seq {sdrdsp::rx-rf sdrdsp::rx-if sdrdsp::rx-af}
    set fopt [list -sequence $seq]
    return [sdrctl::control $name -type dsp -suffix rx -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}

proc sdrdsp::rx-rf {name args} {
    set seq {sdrdsp::comp-gain sdrdsp::comp-iq-swap sdrdsp::comp-iq-delay sdrdsp::comp-spectrum-semi-raw}
    set req {sdrdsp::comp-gain sdrdsp::comp-iq-swap sdrdsp::comp-iq-delay sdrdsp::comp-spectrum}
    # lappend seq sdrdsp::comp-noiseblanker sdrdsp::comp-sdrom-noiseblanker
    # lappend req sdrdsp::comp-noiseblanker
    lappend seq sdrdsp::comp-iq-correct
    lappend req sdrdsp::comp-iq-correct
    set fopt [list -sequence $seq -require $req]
    return [sdrctl::control $name -type dsp -suffix rf -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}

proc sdrdsp::rx-if {name args} {
    set seq {sdrdsp::comp-spectrum-pre-filt sdrdsp::comp-lo-mixer sdrdsp::comp-filter-overlap-save sdrdsp::comp-meter-post-filt sdrdsp::comp-spectrum-post-filt}
    set req {sdrdsp::comp-spectrum sdrdsp::comp-lo-mixer sdrdsp::comp-filter-overlap-save sdrdsp::comp-meter}
    set fopt [list -sequence $seq -require $req]
    return [sdrctl::control $name -type dsp -suffix if -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}

proc sdrdsp::rx-af {name args} {
    set seq {}
    set req {}
    # lappend seq sdrdsp::comp-compand
    # lappend req sdrdsp::comp-compand
    lappend seq sdrdsp::comp-agc sdrdsp::comp-meter-post-agc sdrdsp::comp-spectrum-post-agc sdrdsp::comp-demod
    lappend req sdrdsp::comp-agc sdrdsp::comp-meter sdrdsp::comp-spectrum sdrdsp::comp-demod
    # lappend seq sdrdsp::comp-rx-squelch sdrdsp::comp-spottone sdrdsp::comp-graphic-eq
    # lappend req sdrdsp::comp-rx-squelch sdrdsp::comp-spottone sdrdsp::comp-graphic-eq
    lappend seq sdrdsp::comp-gain
    lappend req sdrdsp::comp-gain
    set fopt [list -sequence $seq -require $req]
    return [sdrctl::control $name -type dsp -suffix af -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}

