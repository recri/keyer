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
package require sdrkit::common-component

namespace eval sdrkit {}

snit::type sdrkit::more-control {    
    option -name more-control
    option -type ctl
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {}

    option -sub-controls {
	ports button {-label {Port Connections} -text View}
	options button {-label {Option Connections} -text View}
	active button {-label {Active Connections} -text View}
	config button {-label {Check Config} -text Check}
    }

    variable data -array {}

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor {}
    method build-parts {w} { if {$w eq {none}} { $self build $w {} {} {} } }
    method build-ui {w pw minsizes weights} { if {$w ne {none}} { $self build $w $pw $minsizes $weights } }
    method build {w pw minsizes weights} {
	if {$w ne {none}} {
	    foreach {opt type opts} $options(-sub-controls) {
		switch $opt {
		    ports { lappend opts -command [mymethod ViewConnections port] }
		    options { lappend opts -command [mymethod ViewConnections opt] }
		    active { lappend opts -command [mymethod ViewConnections active] }
		    config { lappend opts -command [mymethod CheckConfig config] }
		}
		if {[info exists options(-$opt]} {
		    $self window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
		} else {
		    $self window $w $opt $type $opts {} {} {}
		}
		grid $w.$opt -sticky ew
	    }
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
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
    method CheckConfig {val} {
	foreach command {
	    rxtx-rx-rf-gain
	    rxtx-rx-rf-iq-swap
	    rxtx-rx-rf-iq-delay
	    rxtx-rx-rf-iq-correct
	    rxtx-rx-if-lo-mixer
	    rxtx-rx-if-bpf
	    rxtx-rx-af-agc
	    rxtx-rx-af-gain
	} {
	    catch {sdrkitv::$command cget -enable} enable
	    #catch {sdrkitw::$command configure} kitw
	    catch {sdrkitx::$command is-active} active
	    set kitx {}
	    foreach {option} [sdrkitx::$command configure] {
		lassign $option opt name class def val
		if {$opt ni {-client -server -verbose}} {
		    lappend kitx $opt $val
		}
	    }
	    puts "$command enable=$enable active=$active $kitx"
	}
	puts "rxtx-rx-af-demod enable=[sdrkitv::rxtx-rx-af-demod cget -enable] -mode [sdrkitw::rxtx-rx-af-demod cget -mode]"
    }
}
