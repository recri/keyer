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

package provide sdrblk::tx 1.0.0

package require sdrblk::block

namespace eval sdrblk {}

proc sdrblk::tx {name args} {
    set seq {sdrblk::tx-af sdrblk::tx-if sdrblk::tx-rf}
    return [sdrblk::block $name -type sequence -suffix tx -sequence $seq {*}$args]
}

proc sdrblk::tx-af {name args} {
    set seq {sdrblk::comp-gain}
    set req {sdrblk::comp-gain}
    # lappend seq sdrblk::comp-real sdrblk::comp-waveshape
    # lappend req sdrblk::comp-real sdrblk::comp-waveshape
    lappend seq sdrblk::comp-meter-waveshape
    lappend req sdrblk::comp-meter
    # lappend seq sdrblk::comp-dc-block sdrblk::comp-tx-squelch sdrblk::comp-grapic-eq
    # lappend req sdrblk::comp-dc-block sdrblk::comp-tx-squelch sdrblk::comp-grapic-eq
    lappend seq sdrblk::comp-meter-graphic-eq sdrblk::comp-leveler sdrblk::comp-meter-leveler
    lappend req sdrblk::comp-meter sdrblk::comp-leveler
    # lappend seq sdrblk::comp-speech-processor
    # lappend req sdrblk::comp-speech-processor
    lappend seq sdrblk::comp-meter-speech-processor
    lappend req sdrblk::comp-meter
    # lappend seq sdrblk::comp-modulate
    # lappend req sdrblk::comp-modulate

    # a lot of this is voice specific
    # CW only has a keyed oscillator feeding into the LO mixer
    # hw-softrock-dg8saq should have an option to poll keystate and insert as midi
    # hw-softrock-dg8saq should by default convert midi control to dg8saq, both directions
    return [sdrblk::block $name -type sequence -suffix af -sequence $seq -require $req {*}$args]
}

proc sdrblk::tx-if {name args} {
    set seq {sdrblk::comp-filter-overlap-save}
    set req {sdrblk::comp-filter-overlap-save}
    # lappend seq sdrblk::comp-compand
    # lappend req sdrblk::comp-compand
    lappend seq sdrblk::comp-meter-compand sdrblk::comp-spectrum-tx sdrblk::comp-lo-mixer
    lappend req sdrblk::comp-meter sdrblk::comp-spectrum sdrblk::comp-lo-mixer
    return [sdrblk::block $name -type sequence -suffix if -sequence $seq -require $req {*}$args]
}

proc sdrblk::tx-rf {name args} {
    set seq {sdrblk::comp-iq-balance sdrblk::comp-gain sdrblk::comp-meter-power}
    set req {sdrblk::comp-iq-balance sdrblk::comp-gain sdrblk::comp-meter}
    return [sdrblk::block $name -type sequence -suffix rf -sequence $seq -require $req {*}$args]
}

