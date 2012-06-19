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
# a spectrum tap component, just a marker in the graph
#
package provide sdrkit::spectrum-tap 1.0.0

package require snit
package require sdrkit::common-component

namespace eval sdrkit {}

snit::type sdrkit::spectrum-tap {    
    option -name spectrum-tap
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {i q}
    option -out-ports {i q}
    option -options {}

    variable data -array { activate 0 }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
}
