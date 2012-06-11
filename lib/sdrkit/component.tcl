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
# a component encapsulates an sdrtcl::dsp computation
# registers as a sdrkit::control component for external control
# and optionally provides a default tk user interface.
#
# the user interface can be packed into the root window,
# packed into a window supplied by a parent component,
# or left unrealized.
#
# the controlling component can be remote and accessed by tk send,
# or local and accessed by procedure call.
#
package provide sdrkit::component 1.0.0

package require snit

package require sdrkit
package require sdrkit::control
package require sdrkit::comm
package require sdrtype::types

namespace eval sdrkit {}
namespace eval sdrkitw {}

snit::type sdrkit::component {
    component subsidiary
    component control

    # the jack client name, and sdrkit::control name
    # used to "send" commands to this component
    # used as the jack client name or as the root jack
    #   client name if more than one client is active
    # used as the sdrkit::control name
    option -name sdrkit-component

    # the jack server name to create clients
    option -server default

    # the component which contains this component
    option -container {}

    # root window for ui options
    # should be {} for .
    # should be a window name for window name
    # should be {none} for no window
    option -window -default {none}
    option -parent-window {none}

    # the sdrkit::control name
    # of the control application
    # used to "send" commands to the control component 
    option -control {}

    # the tk grid parameters for the standard ui stack
    # which displays a stack of windows in a single toplevel
    # frame.
    # these are the minimum sizes and weights
    # for columns 0 and 1 in a grid display
    # column 0 displays the option value with units
    # column 1 displays the scale for adjusting the value
    # other options are generally centered in a column
    # spanning these two.
    option -minsizes {100 200}
    option -weights {1 3}

    # enable or activate this component
    option -enable -default false -configuremethod Configure
    option -activate -default false -configuremethod Configure
    
    # the factory for the subsidiary which we're wrapping
    option -subsidiary {}
    option -subsidiary-opts {}

    # delegate unknown options to the subsidiary
    delegate option * to subsidiary

    # delegate unknown methods to the controller
    # won't work, have a special method call to reach controller
    # delegate method * to control

    variable data -array {
    }

    proc filter-list {name opts from} {
	foreach opt $opts {
	    if {[llength $opt] == 2} {
		lassign $opt tname opt
		if { ! [string match $tname $name]} continue
	    }
	    while {[set i [lsearch $from $opt]] >= 0} {
		set from [lreplace $from $i $i]
	    }
	}
	return $from
    }

    constructor {args} {
	# fetch two options which will not be correct
	# if they disagree with our defaults
	set activated [from args -activate false]
	set enabled [from args -enable false]
	
	# apply the rest of the configuration
	$self configure {*}$args

	#puts "$options(-name) args={$args}, enabled=$enabled, activated=$activated"

	# create our subsidiary 
	package require $options(-subsidiary)
	install subsidiary using $options(-subsidiary) ::sdrkitw::$options(-name) \
	    -server $options(-server) -name $options(-name) \
	    -component $self {*}$options(-subsidiary-opts)

	# determine window setup
	switch $options(-window) {
	    none {
		set options(-parent-window) none
	    }
	    {} {
		package require Tk
		wm title . $options(-name)
		set options(-parent-window) .
		#$subsidiary configure -window $options(-window) -minsizes $options(-minsizes) -weights $options(-weights)
	    }
	    default {
		package require Tk
		if {[winfo exists $options(-window)]} {
		    set options(-parent-window) [winfo parent $options(-window)]
		    #$subsidiary configure -window $options(-window) -minsizes $options(-minsizes) -weights $options(-weights)
		} else {
		    error "invalid window: $options(-window)"
		}
	    }
	}

	# determine control setup
	if {$options(-control) ne {}} {
	    set control $options(-control)
	} else {
	    # look for controller
	    if {[info commands ::sdrkit-control] eq {}} {
		# make one
		::sdrkit::control ::sdrkit-control -server $options(-server)
	    }
	    set control [::sdrkit-control controller]
	}

	# set up control
	$self control part-add $options(-name) [sdrkit::comm::wrap $self]

	# build the subsidiary parts
	$subsidiary build-parts $options(-window)

	# build the ui
	set w $options(-window)
	if {$w eq {none}} {
	    set pw {}
	} elseif {$w eq {}} {
	    set pw .
	} else {
	    set pw $w
	}
	$subsidiary build-ui $w $pw $options(-minsizes) $options(-weights)
	if {$options(-window) eq {}} {
	    bind . <Destroy> [mymethod destroy]
	}
	
	# find the parts of the subsidiary which are optional
	foreach m {resolve rewrite-connections-to rewrite-connections-from port-complement is-active activate deactivate} {
	    set data(subsidiary-$m) [expr {$m in [$subsidiary info methods]}]
	}
	foreach o {-enable -activate} {
	    set data(subsidiary-configure$o) [expr {$o in [$subsidiary info options]}]
	}
	
	if {$enabled || [$subsidiary cget -type] ni {jack}} {
	    $control part-enable $options(-name)
	}

	# if we made the controller, we're the root component
	if {$control ne $options(-control)} {
	    # resolve the remaining connections
	    $control resolve
	    # activate if requested
	    #puts "$options(-name) $options(-activate)"
	    if {$activated} { $control part-activate $options(-name) }
	    # dump the tree
	    #foreach part [$control part-list] {
	    #puts "$part enabled [$control part-is-enabled $part] active [$control part-is-active $part]"
	    #}
	}
    }
    destructor {
	catch {$subsidiary destroy}
    }
    
    method Configure {opt val} {
	#puts "$options(-name) configure $opt $val"
	set options($opt) $val
	if {$subsidiary ne {}} {
	    if {$data(subsidiary-configure$opt)} { $subsidiary configure $opt $val }
	    switch -- $opt {
		-activate {
		    if {$val} {
			if {$data(subsidiary-activate)} { $subsidiary activate }
		    } else {
			if {$data(subsidiary-deactivate)} { $subsidiary deactivate }
		    }
		}
	    }
	}
    }
    
    #
    # callbacks from subsidiary requesting controller method
    #
    method get-controller {} { return $control }
    method get-parent {} { return $options(-container) }
    #
    # call the controller
    #
    method control {args} { return [sdrkit::comm::send $control {*}$args] }
    #
    # rewritten call from subsidiary reporting option changes
    #
    method report {args} { $self control part-report $options(-name) {*}$args }
    #
    # calls to the controller from the subsidiary
    #
    method part-exists {args} { return [$self control part-exists {*}$args] }
    method part-report {args} { return [$self control part-report {*}$args] }
    method part-configure {args} { return [$self control part-configure {*}$args] }
    method part-cget {args} { return [$self control part-cget {*}$args] }
    method part-is-enabled {args} { return [$self control part-is-enabled {*}$args] }
    method part-enable {args} { return [$self control part-enable {*}$args] }
    method part-disable {args} { return [$self control part-disable {*}$args] }
    method part-is-activated {args} { return [$self control part-is-activated {*}$args] }
    method part-activate {args} { return [$self control part-activate {*}$args] }
    method part-deactivate {args} { return [$self control part-deactivate {*}$args] }
    method part-destroy {args} { return [$self control part-destroy {*}$args] }
    method opt-exists {args} { return [$self control opt-exists {*}$args] }
    method opt-add {args} { return [$self control opt-add {*}$args] }
    method opt-filter {args} { return [$self control opt-filter {*}$args] }
    method port-exists {args} { return [$self control port-exists {*}$args] }
    method port-filter {args} { return [$self control port-filter {*}$args] }
    method port-connect {args} { return [$self control port-connect {*}$args] }
    method opt-connect {args} { return [$self control opt-connect {*}$args] }
    method connect-ports {n1 p1 n2 p2} { return [$self control port-connect [list $n1 $p1] [list $n2 $p2]] }
    method connect-options {n1 o1 n2 o2} { return [$self control opt-connect [list $n1 $o1] [list $n2 $o2]] }
    method out-ports {args} { return [$self control part-out-ports {*}$args] }	
    method in-ports {args} { return [$self control part-in-ports {*}$args] }	
    #
    # call from the controller to the subsidiary
    #
    method resolve {} {
	if {$data(subsidiary-resolve)} { $subsidiary resolve }
    }
    
    method rewrite-connections-to {port candidates} {
	if {$data(subsidiary-rewrite-connections-to)} { return [$subsidiary rewrite-connections-to $port $candidates] }
	return $candidates
    }
    method rewrite-connections-from {port candidates} {
	if {$data(subsidiary-rewrite-connections-from)} { return [$subsidiary rewrite-connections-from $port $candidates] }
	return $candidates
    }
    method port-complement {port} {
	if {$data(subsidiary-port-complement)} { return [$subsidiary port-complement $port] }
	switch -exact $port {
	    in_i { return {out_i} }
	    in_q { return {out_q} }
	    out_i { return {in_i} }
	    out_q { return {in_q} }
	    midi_in { return {midi_out} }
	    midi_out { return {midi_in} }
	    default { error "unknown port \"$port\"" }
	}
    }
    #
    # convenience calls from the subsidiary
    # one to make a subcomponent, with a subsidiary name,
    # one to make a component with fully specified name
    #
    # eliminate all options that can be inherited by
    # asking $options(-container),
    # ie -server -control -minsizes -weights can all
    # be gotten from -container.
    #
    method sub-component {window name subsub args} {
	$self new-component $window $options(-name)-$name $subsub {*}$args
    }
    method new-component {window name subsub args} {
	set argv [list -window $window]
	if {$window ne {none}} {
	    lappend argv -minsizes $options(-minsizes) -weights $options(-weights)
	}
	package require $subsub
	::sdrkit::component ::sdrkitv::$name \
	    {*}$argv \
	    -server $options(-server) \
	    -name $name \
	    -subsidiary $subsub -subsidiary-opts $args \
	    -container $self \
	    -control [$self get-controller]
    }
    method destroy-sub-parts {parts} {
	foreach part $parts { $self part-destroy $options(-name)-$part }
    }	
}
