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
# the rx control component
#
package provide sdrkit::more-control 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::more-control {    
    option -name more-control
    option -type ctl
    option -server default
    option -component {}

    option -window none
    option -title {More Control}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {}
    option -in-options {}
    option -out-options {}

    option -sub-controls {
	ports button {-label {Port Connections} -text View}
	options button {-label {Option Connections} -text View}
	active button {-label {Active Connections} -text View}
    }

    variable data -array {}

    constructor {args} {
	$self configure {*}$args
    }
    destructor {}
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	    foreach {opt type opts} $options(-sub-controls) {
		switch $opt {
		    ports { lappend opts -command [mymethod ViewConnections port] }
		    options { lappend opts -command [mymethod ViewConnections opt] }
		    active { lappend opts -command [mymethod ViewConnections active] }
		}
		switch $type {
		    button {
			package require sdrkit::label-button
			sdrkit::label-button $w.$opt {*}$opts
		    }
		    spinbox {
			package require sdrkit::label-spinbox
			sdrkit::label-spinbox $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		    }
		    scale {
			package require sdrkit::label-scale
			#lappend opts -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max]
			sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		    }
		    separator {
			ttk::separator $w.$opt
		    }
		    radio {
			package require sdrkit::label-radio
			#lappend opts -defaultvalue $options(-$opt) -values [sdrtype::agc-$opt cget -values]
			sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		    }
		}
		grid $w.$opt -sticky ew
	    }
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }
    method ViewConnections {flavor} {
	if { ! [winfo exists .$flavor-connections]} {
	    package require sdrkit::connections
	    toplevel .$flavor-connections
	    pack [::sdrkit::connections .$flavor-connections.x \
		      -show $flavor \
		      -server $options(-server) \
		      -container $options(-component) \
		      -control [$options(-component) get-controller]] -side top -fill both -expand true
	} else {
	    wm deiconify .$flavor-connections
	}
    }
}
