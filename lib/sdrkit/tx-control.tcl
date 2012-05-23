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
# the tx control component
#
package provide sdrkit::tx-control 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::tx-control {    
    option -name tx-control
    option -type ctl
    option -server default
    option -component {}

    option -window none
    option -title {TX Control}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {}
    option -in-options {}
    option -out-options {}

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

    proc split-command-args {command} {
	set args {}
	if {[llength $command] > 1} {
	    set args [lrange $command 1 end]
	    set command [lindex $command 0]
	}
	return [list $command $args]
    }

    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)

	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
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
	foreach {name title command} $options(-sub-components) {
	    lassign [split-command-args $command] command args
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		$self sub-component [ttk::frame $w.$name] $name sdrkit::$command {*}$args
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }

    method is-needed {} { return 1 }

    method is-active {} { return 1 }
    method activate {} { }
    method deactivate {} { }

    method OptionConstrain {opt val} { return $val }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {
	lappend data(deferred-config) $opt $val
	if { ! [$self is-busy]} {
	    ::sdrkitx::$options(-name) configure {*}$data(deferred-config)
	    set data(deferred-config) {}
	}
    }
    method LabelConfigure {opt val} { set data(label$opt) [format $data(format$opt) $val] }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
    }
    method Changed {opt} { $self Set $opt $options($opt) }
}
