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

package provide sdrblk::rx 1.0.0

package require sdrblk::block

namespace eval sdrblk {}

proc sdrblk::rx {name args} {
    set pipe {sdrblk::rx-rf sdrblk::rx-if sdrblk::rx-af}
    return [sdrblk::block $name -type sequence -suffix rx -sequence $pipe {*}$args]
}

proc sdrblk::rx-rf {name args} {
    set seq {sdrblk::comp-gain sdrblk::comp-iq-swap sdrblk::comp-iq-delay sdrblk::comp-spectrum-semi-raw}
    set req {sdrblk::comp-gain sdrblk::comp-iq-swap sdrblk::comp-iq-delay sdrblk::comp-spectrum}
    # lappend seq sdrblk::comp-noiseblanker sdrblk::comp-sdrom-noiseblanker
    # lappend req sdrblk::comp-noiseblanker
    lappend seq sdrblk::comp-iq-correct
    lappend req sdrblk::comp-iq-correct
    return [sdrblk::block $name -type sequence -suffix rf -sequence $seq -require $req {*}$args]
}

proc sdrblk::rx-if {name args} {
    set seq {sdrblk::comp-spectrum-pre-filt sdrblk::comp-lo-mixer sdrblk::comp-filter-overlap-save sdrblk::comp-meter-post-filt sdrblk::comp-spectrum-post-filt}
    set req {sdrblk::comp-spectrum sdrblk::comp-lo-mixer sdrblk::comp-filter-overlap-save sdrblk::comp-meter}
    return [sdrblk::block $name -type sequence -suffix if -sequence $seq -require $req {*}$args]
}

proc sdrblk::rx-af {name args} {
    set seq {}
    set req {}
    # lappend seq sdrblk::comp-compand
    # lappend req sdrblk::comp-compand
    lappend seq sdrblk::comp-agc sdrblk::comp-meter-post-agc sdrblk::comp-spectrum-post-agc sdrblk::comp-demod
    lappend req sdrblk::comp-agc sdrblk::comp-meter sdrblk::comp-spectrum sdrblk::comp-demod
    # lappend seq sdrblk::comp-rx-squelch sdrblk::comp-spottone sdrblk::comp-graphic-eq
    # lappend req sdrblk::comp-rx-squelch sdrblk::comp-spottone sdrblk::comp-graphic-eq
    lappend seq sdrblk::comp-gain
    lappend req sdrblk::comp-gain
    return [sdrblk::block $name -type sequence -suffix af -sequence $seq -require $req {*}$args]
}

