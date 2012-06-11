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
# the keyer control component
#
package provide sdrkit::keyer-control 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::keyer-control {    
    option -name keyer-control
    option -type ctl
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {}

    option -sub-controls {
    }

    option -sub-components {
    }

    variable data -array {}

    constructor {args} {
	$self configure {*}$args
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
	    foreach {opt type opts} $options(-sub-controls) {
		switch $type {
		    spinbox {
			package require sdrkit::label-spinbox
			sdrkit::label-spinbox $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		    }
		    scale {
			package require sdrkit::label-scale
			sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		    }
		    separator {
			ttk::separator $w.$opt
		    }
		    radio {
			package require sdrkit::label-radio
			sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		    }
		}
		grid $w.$opt -sticky ew
	    }
	}
	foreach {name title command args} $options(-sub-components) {
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		$self sub-component [ttk::frame $w.$name] $name sdrkit::$command {*}$args
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
	}
    }

    method is-needed {} { return 1 }
    method is-busy {} { return 0 }
    method is-active {} { return 1 }
    method activate {} { }
    method deactivate {} { }

}
