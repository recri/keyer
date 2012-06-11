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
# a physical port component
#
package provide sdrkit::physical-port 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::physical-port {    
    option -name port
    option -type physical
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {}

    option -ports {}

    variable data -array {
    }

    constructor {args} {
	$self configure {*}$args
	foreach port $options(-ports) {
	    if {[string match *capture* $port]} {
		lappend options(-in-ports) $port
	    } elseif {[string match *playback* $port]} {
		lappend options(-out-ports) $port
	    } else {
		error "no match to port \"$port\" in $options(-name) constructor"
	    }
	}
    }
    method build-parts {w} {}
    method build-ui {w pw minsizes weights} {}
    method is-needed {} { return 1 }
}
