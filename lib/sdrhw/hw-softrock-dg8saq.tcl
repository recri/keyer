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

package provide sdrhw::hw-softrock-dg8saq 1.0.0

package require snit

namespace eval sdrhw {}

proc sdrhw::hw-softrock-dg8saq {name args} {
    return [sdrctl::control $name -type hw -suffix softrock -factory sdrhw::softrock-dg8saq {*}$args]
}

snit::type sdrhw::softrock-dg8saq {
    option -ports -default {}
    option -opts -default {-freq}
    option -methods -default {}

    option -opt-connect-from { {ctl-rxtx-tuner -hw-freq -freq} }

    option -freq -default 7.050 -configuremethod Handler

    option -command {}

    variable data -array {
	activate 0
    }

    constructor {args} {
	# puts "radio-hw-softrock-dg8saq $self constructor $args"
	$self configure {*}$args
    }

    method activate {} { set data(activate) 1 }
    method deactivate {} { set data(activate) 0 }

    method {Handler -freq} {val} {
	puts "hw-softrock-dg8saq -freq $val"
	set options(-freq) $val
	if {$data(activate)} { exec usbsoftrock set freq [expr {$val/1e6}] }
    }
}
