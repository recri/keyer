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
# a composite component that builds a transceiver
#
package provide sdrkit::rxtx 1.0.0

package require snit
package require sdrtk::cnotebook
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::rxtx {
    option -name sdr-src
    option -type dsp
    option -title {IQ Source}
    option -in-ports {}
    option -out-ports {out_i out_q}
    option -in-options {}
    option -out-options {}
    #ctl {Control} rxtx-control
    option -sub-components {
	rx {Receiver} rx
	tx {Transmitter} tx
	keyer {Keyer} keyer
    }
    option -connections {
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -rx-source {}
    option -rx-sink {}
    option -rx-enable {}
    option -rx-activate {}
    option -tx-source {}
    option -tx-sink {}
    option -keyer-source {}
    option -keyer-sink {}
    option -physical true
    option -hardware {}

    variable data -array {
	parts {}
	active 0
    }

    constructor {args} {
	# puts "rxtx constructor $args"
	$self configure {*}$args
    }
    destructor {
	foreach name $data(parts) {
	    $options(-component) name-destroy $options(-name)-$name
	}
    }
    method sub-component {name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $name $subsub {*}$args
    }
    method sub-window {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-window $window $name $subsub {*}$args
    }
    method build-common {} {
	if {$options(-physical) ne {}} {
	    $self sub-component ports sdrkit::physical-ports -physical $options(-physical)
	    $options(-component) part-configure $options(-name)-ports -enable true -activate true
	}
	if {$options(-hardware) ne {}} {
	    $self sub-component hardware sdrkit::hardware -hardware $options(-hardware)
	}
    }
    proc split-command-args {command} {
	set args {}
	if {[llength $command] > 1} {
	    set args [lrange $command 1 end]
	    set command [lindex $command 0]
	}
	return [list $command $args]
    }
    method build-parts {} {
	if {$options(-window) ne {none}} return
	$self build-common
	foreach {name title command} $options(-sub-components) {
	    lassign [split-command-args $command] command args
	    $self sub-component $name sdrkit::$command {*}$args
	}
    }
    method build-ui {} {
	if {$options(-window) eq {none}} return
	set w $options(-window)
	if {$w eq {}} { set pw . } else { set pw $w }
	
	$self build-common
	grid [ttk::frame $w.menu] -sticky ew
	pack [ttk::button $w.menu.connections -text connections -command [mymethod ViewConnections]] -side left
	sdrtk::cnotebook $w.note
	foreach {name title command} $options(-sub-components) {
	    lassign [split-command-args $command] command args
	    switch $name {
		rx { lappend args -rx-source $options(-rx-source) -rx-sink $options(-rx-sink) }
		tx { lappend args -tx-source $options(-tx-source) -tx-sink $options(-tx-sink) }
		keyer { lappend args -keyer-source $options(-keyer-source) -keyer-sink $options(-keyer-sink) }
	    }
	    $self sub-window [ttk::frame $w.note.$name] $name sdrkit::$command {*}$args
	    $w.note add $w.note.$name -text $title
	}
	grid $w.note -sticky nsew -row 1
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method resolve-parts {} {
	foreach {name1 ports1 name2 ports2} $options(-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	if {$options(-rx-enable) ne {} && $options(-rx-enable)} {
	    $options(-component) part-enable $options(-name)-rx
	}
	if {$options(-rx-activate) ne {} && $options(-rx-activate)} {
	    $options(-component) part-activate $options(-name)-rx
	}
    }
    method ViewConnections {} {
	if { ! [winfo exists .connections]} {
	    package require sdrkit::connections
	    toplevel .connections
	    pack [::sdrkit::connections .connections.x \
		      -server $options(-server) \
		      -container $options(-component) \
		      -control [$options(-component) get-controller]] -side top -fill both -expand true
	} else {
	    wm deiconify .connections
	}
    }
    method is-active {} { return $data(active) }
    method activate {} {
	set data(active) 1
	foreach part $data(parts) {
	}
    }
    method deactivate {} {
	set data(active) 1
	foreach part $data(parts) {
	}
    }
    method Enable {name} {
	if {$data($name-enable)} {
	    $options(-component) part-enable $options(-name)-$name
	} else {
	    $options(-component) part-disable $options(-name)-$name
	}
    }
}
