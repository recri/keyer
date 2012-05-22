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
package require sdrtcl::jack

namespace eval sdrkit {}

snit::type sdrkit::physical-ports {    
    option -name ports
    option -type dsp
    option -server default
    option -component {}

    option -window none
    option -title Ports
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {}
    option -in-options {}
    option -out-options {}

    option -physical {}

    variable data -array {
	parts {}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	foreach part $data(parts) {
	    if {[catch {$options(-component) part-destroy $part} error]} {
		puts "error cleaning up ports for $part: $error"
	    }
	}
    }
    method sub-component {name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $name $subsub {*}$args
    }
    method build-parts {} {
	set clients [dict create]
	foreach {pname pdict} [sdrtcl::jack -server $options(-server) list-ports] {
	    # pdict has type, direction, physical, and connections
	    if {[dict get $pdict physical] ||
		[string match audioadapter:* $pname]} {
		dict lappend clients {*}[split $pname :]
	    }
	}
	dict for {client ports} $clients {
	    $self sub-component $client sdrkit::physical-port -ports $ports
	    $options(-component) part-configure $options(-name)-$client -enable true -activate true
	}
    }
    method build-ui {} {}
    method is-needed {} { return 1 }
    method is-active {} { return 1 }
    method activate {} { }
    method deactivate {} { }
}
