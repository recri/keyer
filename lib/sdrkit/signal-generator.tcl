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

package provide sdrkit::signal-generator 1.0.0

package require snit
package require sdrkit::common-component
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::signal-generator {
    option -name sdr-sg
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {out_i out_q}
    option -options {}

    option -sub-components {
	osc1 {Oscillator 1} oscillator {}
	osc2 {Oscillator 2} oscillator {}
	osc3 {Oscillator 3} oscillator {}
	osc4 {Oscillator 4} oscillator {}
	noise Noise noise {}
	iq-noise {IQ Noise} iq-noise {}
	out {Master Gain} gain {}
    }
    option -port-connections {
	osc1 out-ports out in-ports
	osc2 out-ports out in-ports
	osc3 out-ports out in-ports
	osc4 out-ports out in-ports
	noise out-ports out in-ports
	iq-noise out-ports out in-ports
	out out-ports {} out-ports
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
    method build-parts {w} { if {$w eq {none}} { $self build $w {} {} {} } }
    method build-ui {w pw minsizes weights} { if {$w ne {none}} { $self build $w $pw $minsizes $weights } }
    method build {w pw minsizes weights} {
	foreach {name title command args} $options(-sub-components) {
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		sdrtk::clabelframe $w.$name -label $title
		set data($name-enable) 0
		ttk::checkbutton $w.$name.enable -text {} -variable [myvar data($name-enable)] -command [mymethod Enable $name]
		ttk::frame $w.$name.container
		$self sub-component $w.$name.container $name sdrkit::$command {*}$args
		grid $w.$name.enable $w.$name.container
		grid $w.$name -sticky ew
		grid columnconfigure $w.$name 1 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
	}
    }
    method resolve {} {
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		#puts "$options(-component) connect-ports $name1 $p1 $name2 $p2"
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	foreach {name1 opt1 name2 opt2} $options(-opt-connections) {
	}
    }
    method part-is-enabled {name} { return [$options(-component) part-is-enabled $options(-name)-$name] }
    method Enable {name} {
	if {$data($name-enable)} {
	    if {! [$self part-is-enabled $name]} {
		$options(-component) part-enable $options(-name)-$name
	    }
	} else {
	    if {[$self part-is-enabled $name]} {
		$options(-component) part-disable $options(-name)-$name
	    }
	}
    }
}


