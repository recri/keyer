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

package provide input 1.0.0

package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::iq-swap
#package require sdrblk::gain
#package require sdrblk::iq-delay
#package require sdrblk::iq-correct
#package require sdrblk::audio-tap

::snit::type input {

    option -server -default default
    option -gain -default 0 -validatemethod ValidateDouble -configuremethod SetGain
    option -iq-swap -default false -validatemethod ValidateBoolean -configuremethod SetSwap
    option -iq-delay -default 0 -validatemethod ValidateInteger -configuremethod SetDelay
    option -iq-correct -default false -validatemethod ValidateBoolean -configuremethod SetCorrect
    option -mu -default -4 -validatemethod ValidateInteger -configuremethod SetMu
    option -inputs -default {system:capture_1 system:capture_2} -configuremethod SetInputs
    option -outputs -default {lo-mixer:in_i lo-mixer:in_q} -configuremethod SetOutputs
    constructor {args} {
	$self configure {*}$args
    }

    method ValidateDouble {opt val} {
	if {![string is double -strict $val]} {
	    error "expected a double value, got \"$val\""
	}
    }
    method ValidateBoolean {opt val} {
	if {![string is boolean -strict $val]} {
            error "expected a boolean value, got \"$val\""
        }
    }
    method ValidateInteger {opt val} {
	if {![string is integer -strict $val]} {
            error "expected a boolean value, got \"$val\""
        }
    }
    
    method SetGain {opt val} {
	if {$val != 0} {
	    if {$options($opt) == 0} {
		# instantiate, configure, and connect gain block
	    } else {
		# configure gain block
	    }
	} else {
	    if {$options($opt) == 0} {
		# do nothing
	    } else {
		# disconnect and destroy gain block, reconnect remnant
	    }
	}
    }
    method SetMu {opt val} {
	set options($opt) $val
	if {$options(-iq-correct)} {
	    iq_correct configure $opt $val
	}
    }
}
