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
# a component that installs physical jack ports
#
package provide sdrkit::physical-ports 1.0.0

package require snit
package require sdrkit::common-component
package require sdrtcl::jack

namespace eval sdrkit {}

snit::type sdrkit::physical-ports {    
    option -name ports
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {}

    option -physical {}

    variable data -array {
	parts {}
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method new-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) new-component $window $name $subsub {*}$args
    }
    method build-parts {w} {
	set clients [dict create]
	foreach {pname pdict} [sdrtcl::jack -server $options(-server) list-ports] {
	    # pdict has type, direction, physical, and connections
	    if {[dict get $pdict physical] || [string match audioadapter:* $pname]} {
		dict lappend clients {*}[split $pname :]
	    }
	}
	foreach client [lsort [dict keys $clients]] {
	    set ports [dict get $clients $client]
	    $self new-component none $client sdrkit::physical-port -ports $ports
	    $options(-component) part-configure $client -activate true
	}
    }
    method build-ui {w pw minsizes weights} {}
    method is-needed {} { return 1 }
    method is-active {} { return 1 }
    method activate {} { }
    method deactivate {} { }
}
