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
# a composite component that synthesizes an IQ sample stream
# and unbalances it
#
package provide sdrkit::iq-source 1.0.0

package require snit
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::iq-source {
    option -name sdr-src
    option -type dsp
    option -title {IQ Source}
    option -in-ports {}
    option -out-ports {out_i out_q}
    option -in-options {}
    option -out-options {}
    option -sub-components {
	sg {Signal Generator} signal-generator
	iq {IQ Imbalance} iq-unbalance
    }
    option -connections {
	sg out-ports iq in-ports
	iq out-ports {} out-ports
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    variable data -array {
	parts {}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method resolve-parts {} {
	foreach {name1 ports1 name2 ports2} $options(-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
    }
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	}
	foreach {name title command args} $options(-sub-components) {
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		$self sub-component [ttk::frame $w.$name] $name sdrkit::$command {*}$args
		grid $w.$name -sticky ew
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }
    method is-active {} { return 1 }
    method activate {} {}
    method deactivate {} {}
}
