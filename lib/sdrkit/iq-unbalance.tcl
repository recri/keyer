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
# a composite component that unbalances IQ sample stream
#
package provide sdrkit::iq-unbalance 1.0.0

package require snit
package require sdrkit::common-component
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::iq-unbalance {
    option -name sdr-iqu
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -options {}

    option -sub-components {
	swp {IQ Swap} iq-swap {}
	dly {IQ Delay} iq-delay {}
	bal {IQ Balance} iq-balance {}
    }
    option -port-connections {
	{} in-ports swp in-ports
	swp out-ports dly in-ports
	dly out-ports bal in-ports
	bal out-ports {} out-ports
    }
    option -opt-connections {
    }

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method resolve {} {
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	foreach {name1 opts1 name2 opts2} $options(-opt-connections) {
	}
    }
    method build-parts {w} {
	if {$w ne {none}} return
	foreach {name title command args} $options(-sub-components) {
	    $self sub-component none $name sdrkit::$command {*}$args
	}
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {name title command args} $options(-sub-components) {
	    grid [sdrtk::clabelframe $w.$name -label $title] -sticky ew
	    set data($name-enable) 0
	    ttk::checkbutton $w.$name.enable -text {} -variable [myvar data($name-enable)] -command [mymethod Enable $name]
	    $self sub-component [ttk::frame $w.$name.container] $name sdrkit::$command {*}$args
	    grid $w.$name.enable $w.$name.container
	    grid columnconfigure $w.$name 1 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
    method is-active {} { return 1 }
    method activate {} {}
    method deactivate {} {}
    method Enable {name} {
	if {$data($name-enable)} {
	    $options(-component) part-enable $options(-name)-$name
	} else {
	    $options(-component) part-disable $options(-name)-$name
	}
    }
}

