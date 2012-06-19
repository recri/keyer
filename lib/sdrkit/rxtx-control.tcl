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
# the rxtx control component
#
package provide sdrkit::rxtx-control 1.0.0

package require snit
package require sdrkit::common-component
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::rxtx-control {    
    option -name rxtx-control
    option -type ctl
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {}

    option -sub-controls {
    }
    #split radio {-format {Split} -values {0 1} -labels {Off On}}
    #qsk radio {-format {QSK} -values {0 1} -labels {Off On}}

    option -sub-components {
	more {More Controls} more-control {}
    }

    #option -split -default 0 -configuremethod Configure
    #option -qsk -default 0 -configuremethod Configure

    variable data -array {}

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
	if {$w ne {none}} {
	    set name rxtx
	    set title RXTX
	    sdrtk::clabelframe $w.$name -label $title
	    grid $w.$name -sticky ew
	    foreach {opt type opts} $options(-sub-controls) {
		if {[info exists options(-$opt]} {
		    $self window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
		} else {
		    $self window $w $opt $type $opts {} {} {}
		}
		grid $w.$name.$opt -sticky ew
		grid columnconfigure $w.$name 0 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	    }
	}
	foreach {name title command args} $options(-sub-components) {
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		sdrtk::clabelframe $w.$name -label $title
		grid $w.$name -sticky ew
		$self sub-component [ttk::frame $w.$name.container] $name sdrkit::$command {*}$args
		grid $w.$name.container -sticky ew
		grid columnconfigure $w.$name 0 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
	}
    }
    method Configure {opt val} { set options($opt) [$self Constrain $opt $val] }
    method Set {opt val} { $options(-component) report $opt [$self Constrain $opt $val] }
}
