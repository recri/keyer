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

package provide sdrctl::control 1.0.0

package require snit

package require sdrtcl::jack
package require sdrctl::types

namespace eval sdrctl {}

#
# this is the control component that wraps every
# user interface, dsp computation, and control transfer
# component.
# the controller is further down below
#
snit::type sdrctl::control {
    typevariable verbose -array {
	construct 0 inherit 0 configure 0 destroy 0 require 0
	enable 0 activate 0 connect 0 disconnect 0 make-connect 0 make-disconnect 0
	resolution 0 no-resolution 0
    }
    typevariable typedata -array {
	exclude-opts {
	    -command -opts -methods -ports -opt-connect-to -opt-connect-from
	    -server -client -verbose
	}
	exclude-methods {}
	exclude-ports {}
    }

    component wrapped

    option -type -default {}  -readonly yes -type sdrctl::type
    option -control -default {} -readonly yes
    option -container -default {} -readonly yes

    option -root -default {} -readonly yes; # used by ui components only

    option -prefix -default {} -readonly yes
    option -suffix -default {} -readonly yes
    option -name -default {} -readonly yes

    option -server -default default -readonly yes

    option -opts -default {} -readonly yes
    option -methods -default {} -readonly yes
    option -ports -default {} -readonly yes

    option -require -default {} -readonly yes
    option -factory -default sdrctl::control-stub -readonly yes
    option -factory-options -default {} -readonly yes
    option -factory-require -default {} -readonly yes

    option -opt-connect-to -default {} -readonly yes -cgetmethod Delegate
    option -opt-connect-from -default {} -readonly yes -cgetmethod Delegate

    option -enable -default yes
    option -activate -default no -configuremethod Handler

    delegate option * to wrapped
    delegate method * to wrapped

    constructor {args} {
	if {$verbose(construct)} { puts "sdrctl::controll $self constructor {$args}" }
	$self configure {*}$args
	$self Inherit -prefix -name
	$self Inherit -control -control
	$self Inherit -server -server
	set options(-name) [string trim "$options(-prefix)-$options(-suffix)" -]
	foreach pkg $options(-require) { package require $pkg }
	foreach pkg $options(-factory-require) { package require $pkg }
	# puts "create $options(-type) component $options(-name)"
	## okay, lots of abstraction here that m
	install wrapped using $options(-factory) [$self Wrapped name] {*}$options(-factory-options) {*}[$self Wrapped extra-opts]
	if {$options(-type) eq {jack}} { $wrapped deactivate }
	set options(-opts) [$self Wrapped opts]
	set options(-methods) [$self Wrapped methods]
	set options(-ports) [$self Wrapped ports]
	$options(-control) part-add $options(-name) $self
	if {{finish} in [$wrapped info methods]} { $wrapped finish }
    }
    method {Wrapped name} {} {
	switch $options(-type) {
	    ui { return $options(-root).$options(-name) }
	    default { return ::sdrctlx::$options(-name) }
	}
    }
    method {Wrapped extra-opts} {} {
	switch $options(-type) {
	    ctl - ui - hw { return [list -command [mymethod command]] }
	    jack { return {} }
	    dsp { return [list -container $self] }
	}
    }
    method {Wrapped opts} {} {
	if {{-opts} in [$wrapped info options]} {
	    return [$wrapped cget -opts]
	}
	return [Filter-not-in [$wrapped info options] $typedata(exclude-opts)]
    }
    method {Wrapped methods} {} {
	if {{-methods} in [$wrapped info options]} {
	    return [$wrapped cget -methods]
	}
	return [Filter-not-in [$wrapped info methods] $typedata(exclude-methods)]
    }
    method {Wrapped ports} {} {
	if {{-ports} in [$wrapped info options]} {
	    return [$wrapped cget -ports]
	} elseif {$options(-type) eq {jack}} {
	    return [Filter-not-in [$wrapped info ports] $typedata(exclude-ports)]
	}
	return {}
    }
    method resolve {} {
	#puts "$self resolve $options(-type)"
	switch $options(-type) {
	    ctl - ui - hw - dsp {
		foreach conn [$self cget -opt-connect-to] {
		    if {$verbose(resolution)} { puts "$options(-name) opt-connect-to $conn" }
		    $self opt-connect-to {*}$conn
		}
		foreach conn [$self cget -opt-connect-from] {
		    if {$verbose(resolution)} {  puts "$options(-name) opt-connect-from $conn" }
		    $self opt-connect-from {*}$conn
		}
	    }
	    jack {
		foreach opt $options(-opts) {
		    set candidates [$options(-control) opt-filter [list ctl*$options(-name) $opt]]
		    if {[llength $candidates] > 1} {
			error "multiple resolutions (1st pass) for $options(-name):$opt: $candidates"
		    }
		    if {[llength $candidates] == 1} {
			set candidate [lindex $candidates 0]
			if {$verbose(resolution)} { puts "$options(-name) opt-connect-from $candidate $opt" }
			$self opt-connect-from {*}$candidate $opt
			continue
		    }
		    if { ! [regexp {^[rt]x-(.*)$} $options(-name) all tail]} {
			if {$verbose(no-resolution)} { puts "$options(-name): no resolution (1st pass) for $opt" }
			continue
		    }
		    set candidates [$options(-control) opt-filter [list ctl-rxtx*$tail $opt]]
		    if {[llength $candidates] > 1} { error "multiple resolutions (2nd pass) for $options(-name):$opt: $candidates" }
		    if {[llength $candidates] == 1} {
			set candidate [lindex $candidates 0]
			if {$verbose(resolution)} { puts "$options(-name) opt-connect-from $candidate $opt" }
			$self opt-connect-from {*}$candidate $opt
			continue
		    }
		    if {$verbose(no-resolution)} { puts "$options(-name): no resolution (2nd pass) for $opt" }
		}
	    }
	}
    }

    method {command report} {opt val args} { $self report $opt $val {*}$args }
    method opt-connect-to {opt name2 opt2} { $options(-control) opt-connect $options(-name) $opt $name2 $opt2 }
    method opt-connect-from {name2 opt2 opt} { $options(-control) opt-connect $name2 $opt2 $options(-name) $opt }
    method port-connect-to {port name2 port2} { $options(-control) port-connect $options(-name) $port $name2 $port2 }
    method port-connect-from {name2 opt2 opt} { $options(-control) port-connect $name2 $opt2 $options(-name) $opt }
    method report {opt val args} { $options(-control) part-report $options(-name) $opt $val {*}$args }
    
    method Inherit {opt from_opt} {
	if {$options($opt) eq {}} {
	    set options($opt) [$options(-container) cget $from_opt]
	}
    }

    proc Filter-not-in {list nilist} {
	set new {}
	foreach i $list { if {$i ni $nilist} { lappend new $i } }
	return $new
    }

    method {Handler -activate} {val} {
	set options(-activate) $val
	if {$options(-type) eq {jack}} {
	    if {$val} {
		::sdrctlx::$options(-name) activate
	    } else {
		::sdrctlx::$options(-name) deactivate
	    }
	}
    }

    method Delegate {opt} {
	if {$opt in [$wrapped info options]} { return [$wrapped cget $opt] }
	return $options($opt)
    }
}

#
# Okay, redo the controller so it handles both jack and control connections.
# We do get multiple jack inputs and outputs managed for free.
# We don't yet get the make-before-break insertion/deletion of jack components into/from
# active computation graphs.
# We don't yet get the radiobutton logic for alternates disciplines: at-most-one, zero-or-more,
# exactly-one, one-or-more, etc.
# We don't yet get the tap points in the dsp chain because they need to supply dummy ports.
#

snit::type sdrctl::controller {
    option -container -readonly yes
    option -server -readonly yes

    variable data -array {}
    
    constructor {args} {
	set data(part) [dict create]
	set data(opt) [dict create]
	set data(invert-opt) [dict create]
	set data(port) [dict create]
	set data(invert-port) [dict create]
	$self configure {*}$args
    }

    ## part methods
    ## parts are components in the computation which supply
    ## opts and ports that can be wired up
    method part-exists {name} { return [$self X-exists part $name] }
    method part-get {name} { return [$self X-get part $name] }
    method part-add {name command} {
	$self X-add part $name
	dict set data(part) $name $command
	foreach opt [$self part-opts $name] { $self opt-add $name $opt }
	foreach port [$self part-ports $name] { $self port-add $name $port }
    }
    method part-remove {name} {
	if { ! [$self exists part $name]} { error "part \"$name\" does not exist" }
	foreach opt [$self opt filter $name *] { $self remove opt $name $opt }
	foreach port [$self port filter $name *] { $self remove port $name $port }
	dict unset data(parts) $name
    }
    method part-list {} { return [$self X-list part] }
    method part-filter {glob} { return [$self X-filter part $glob] }

    method part-configure {name args} { return [{*}[dict get $data(part) $name] configure {*}$args] }
    method part-cget {name opt} { return [{*}[dict get $data(part) $name] cget $opt] }

    method part-container {name} { return [[$self part-cget $name -container] cget -name] }
    method part-opts {name} { return [$self part-cget $name -opts] }
    method part-ports {name} { return [$self part-cget $name -ports] }
    method part-type {name} { return [$self part-cget $name -type] }
    method part-is-enabled {name} { return [$self part-cget $name -enable] }
    method part-is-active {name} { return [$self part-cget $name -activate] }

    ##
    ## now the tricky stuff, which only applies to the dsp parts of the tree
    ##
    ## by convention, only the jack components are disabled and enabled.  The rest of the graph
    ## is always enabled -- though alternates may effectively enable one or none of their alternate
    ## paths.  Enabling by itself does nothing, it's only marking the component as ready for activation.
    ## Until activated, the jack components are quiescent, they absorb parameters and allocate memory
    ## but they do no processing.
    ##
    ## also by convention, activation is normally applied to the top nodes in the tree and percolates
    ## down through the enabled subtree.  so we activate and deactivate the rx, tx, or keyer nodes to
    ## turn them on and off in their currently enabled configuration.
    ##
    ## but the other thing that happens is that a single jack node can be enabled or disabled inside
    ## an active tree.  this is extra tricky because we want to make the new connection before we
    ## break the old connection, and either the old or new connection is going to be an arc that goes
    ## around the component being enabled or disabled.
    ##
    ## the important thing is that we're not turning on/off arbitrary sub-graphs of the computation.
    ## the two cases are a whole tree of the graph, or a single node of the graph.
    ##
    ## another, possibly misguided, convention is that the names of the parts are built hierarchically
    ## so the sub-nodes of node are all names which extend the root node's name.  That's fine for the
    ## basic radio graph, but it breaks if we make a spectrum or meter component that isn't in the
    ## hierarchy.
    ##
    proc complement {port} {
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
    method port-active-connections-to {pair} {
	# chase each connections-to chain starting from {part port} until you find an active component
	# and return the list of {part port} pairs found.
	# todo - avoid chasing through all the disabled alternates in an alternates block
	set active {}
	foreach source [$self port-connections-to {*}$pair] {
	    lassign $source part port
	    set type [$self part-type $part]
	    if {$type in {jack hw}} {
		if {[$self part-is-active $part]} {
		    # puts "port-active-connections-to: accepted source={$source}"
		    lappend active $source
		} elseif {$type eq {jack}} {
		    set source [list $part [complement $port]]
		    # puts "port-active-connections-to: searching source={$source}"
		    lappend active {*}[$self port-active-connections-to $source]
		}
	    } else {
		# puts "port-active-connections-to: searching source={$source}"
		lappend active {*}[$self port-active-connections-to $source]
	    }
	}
	return $active
    }
    method port-active-connections-from {pair} {
	# chase each connections-from chain starting from {part port} until you find an active component
	# and return the list of active {port part} pairs found
	# todo - avoid chasing through all the disabled alternates in an alternates block
	set active {}
	foreach sink [$self port-connections-from {*}$pair] {
	    lassign $sink part port
	    set type [$self part-type $part]
	    if {$type in {jack hw}} {
		if {[$self part-is-active $part]} {
		    # puts "port-active-connections-from: accepted sink={$sink}"
		    lappend active $sink
		} elseif {$type eq {jack}} {
		    set sink [list $part [complement $port]]
		    # puts "port-active-connections-from: searching sink={$sink}"
		    lappend active {*}[$self port-active-connections-from $sink]
		}
	    } else {
		# puts "port-active-connections-from: searching sink={$sink}"
		lappend active {*}[$self port-active-connections-from $sink]
	    }
	}
	return $active
    }

    method part-activate-tree {name} {
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if { ! [$self part-is-enabled $name]} return
	set activated {}
	$self part-configure $name -activate true
	if {[$self part-type $name] in {jack hw}} {
	    lappend activated $name
	}
	# find the parts to be activated
	foreach part [$self part-filter $name-*] {
	    if {[$self part-is-enabled $part]} {
		$self part-configure $part -activate true
		if {[$self part-type $part] in {jack hw}} {
		    lappend activated $part
		}
	    }
	}
	# now find the active connections to make
	
	# this doesn't quite work right, it finds
	# extra paths through disabled alternates
	# that go around the desired path.
	
	puts "parts to be connected: $activated"
	set connections {}
	foreach part $activated {
	    foreach port [$self part-ports $part] {
		set pair [list $part $port]
		set jackport [join $pair :]
		# puts "part-activate-tree: connections-from {$pair}"
		foreach sink [$self port-active-connections-from $pair] {
		    set connection [list $jackport [join $sink :]]
		    if {[lsearch -exact $connections $connection] < 0} {
			# puts "add connect $connection"
			lappend connections $connection
		    }
		}
		# puts "part-activate-tree: connections-to {$pair}"
		foreach source [$self port-active-connections-to $pair] {
		    set connection [list [join $source :] $jackport]
		    if {[lsearch -exact $connections $connection] < 0} {
			# puts "add connect $connection"
			lappend connections $connection
		    }
		}
	    }
	}
	foreach connection $connections {
	    sdrtcl::jack -server $options(-server) connect {*}$connection
	}
    }
    
    # deactivating a tree is simpler, because all the connections go away as each
    # node is deactivated
    method part-deactivate-tree {name} {
	if { ! [$self part-is-active $name]} { error "part \"$name\" is not active" }
	set deactivated {}
	$self part-configure $name -activate false
	foreach part [$self part-filter $name-*] {
	    if {[$self part-is-active $part]} {
		$self part-configure $part -activate false
	    }
	}
    }
    
    method part-activate-node {name} {
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if { ! [$self part-is-enabled $name]} return
	set to {}
	set from {}
	foreach port [$self part-ports $name] {
	    set pair [list $name $port]
	    set jackport [join $pair :]
	    foreach sink [$self port-active-connections-from $pair] {
		set connection [list $jackport [join $sink :]]
		if {[lsearch -exact $from $connection] < 0} {
		    # puts "add connect $connection"
		    lappend from $connection
		}
	    }
	    foreach source [$self port-active-connections-to $pair] {
		set connection [list [join $source :] $jackport]
		if {[lsearch -exact $to $connection] < 0} {
		    # puts "add connect $connection"
		    lappend to $connection
		}
	    }
	}
	puts "part-activate-node: connections-from {$pair} are {$from}"
	puts "part-activate-node: connections-to {$pair} are {$to}"
	
    }
    
    method part-deactivate-node {name} {
	if { ! [$self part-is-active $name]} { error "part \"$name\" is not active" }
    }
    
    method part-enable {name} {
	if {[$self part-is-enabled $name]} { error "part \"$name\" is enabled" }
	$self part-configure $name -enable true
	if {[$self part-is-active [$self part-container $name]]} {
	    $self part-activate-node $name
	}
    }
    method part-disable {name} {
	if {[$self part-is-active $name]} {
	    $self part-deactivate-node $name
	}
	$self part-configure $name -enable false
    }
    
    method part-report {name opt value args} {
	foreach pair [$self opt-connections-from $name $opt] {
	    $self part-configure {*}$pair $value {*}$args
	}
    }
    
    method part-resolve {} {
	foreach part [$self part-list] {
	    {*}[$self part-get $part] resolve
	}
    }
    
    ## opt methods
    ## opts are "configure options" in the tcl/tk sense which the components
    ## expose for connection to opts of other components
    method opt-exists {name opt} { return [$self X-exists opt [list $name $opt]] }
    method opt-connected {name1 opt1 name2 opt2} { return [$self X-connected opt [list $name1 $opt1] [list $name2 $opt2]] }
    method opt-add {name opt} { $self X-add opt [list $name $opt] }
    method opt-remove {name opt} { $self X-remove opt [list $name $opt]} 
    method opt-connect {name1 opt1 name2 opt2} { $self X-connect opt [list $name1 $opt1] [list $name2 $opt2] }
    method opt-disconnect {name1 opt1 name2 opt2} { $self X-disconnect opt [list $name1 $opt1] [list $name2 $opt2] }
    method opt-list {} { return [$self X-list opt] }
    method opt-filter {glob} { return [$self X-filter opt $glob] }
    method opt-connections-to {name opt} { return [$self X-connections-to opt [list $name $opt]] }
    method opt-connections-from {name opt} { return [$self X-connections-from opt [list $name $opt]] }
    
    ## port methods
    ## ports are jack ports, both audio and midi, which the components
    ## expose for connection to ports of other components
    method port-exists {name port} { return [$self X-exists port [list $name $port]] }
    method port-connected {name1 port1 name2 port2} { return [$self X-connected port [list $name1 $port1] [list $name2 $port2]] }
    method port-add {name port} { $self X-add port [list $name $port] }
    method port-remove {name port} { $self X-remove port [list $name $port] }
    method port-connect {name1 port1 name2 port2} { $self X-connect port [list $name1 $port1] [list $name2 $port2] }
    method port-disconnect {name1 port1 name2 port2} { $self X-disconnect port [list $name1 $port1] [list $name2 $port2] }
    method port-list {} { return [$self X-list port] }
    method port-filter {glob} { return [$self X-filter port $glob] }
    method port-connections-to {name port} { return [$self X-connections-to port [list $name $port]] }
    method port-connections-from {name port} { return [$self X-connections-from port [list $name $port]] }
    
    ## X methods to handle common patterns
    ## tag may be a simple part name, or a part name opt name pair, or part name port name pair 
    ## pair will always be a part name opt name pair, or part name port name pair 
    ##
    method X-exists {x tag} { return [dict exists $data($x) $tag] }
    method X-get {x tag} { return [dict get $data($x) $tag] }
    method X-add {x tag} {
	if {[dict exists $data($x) $tag]} { error "$x \"$tag\" exists" }
	dict set data($x) $tag {}
	if {$x in {opt port}} { dict set data(invert-$x) $tag {} }
    }
    method X-remove {x tag} {
	if { ! [dict exists $data($x) $tag]} { error "$x \"$tag\" does not exist" }
	if {$x in {opt port}} {
	    # remove the connections
	    foreach tag2 [dict get $data($x) $tag] { $self X-disconnect $x $tag $tag2 }
	}
	# remove the tag
	dict unset data($x) $tag
    }
    method X-list {x} { return [dict keys $data($x)] }
    method X-filter {x glob} { return [dict keys $data($x) $glob] }
    method X-connected {x pair1 pair2} { return [expr {[lsearch -exact [dict get $data($x) $pair1] $pair2] >= 0}] }
    method X-connect {x pair1 pair2} {
	if { ! [dict exists $data($x) $pair1]} { error "$x \"$pair1\" does not exist" }
	if { ! [dict exists $data($x) $pair2]} { error "$x \"$pair2\" does not exist" }
	if {[$self X-connected $x $pair1 $pair2]} { error "${x}s \"$pair1\" \"$pair2\" are connected" }
	dict lappend data($x) $pair1 $pair2
	dict lappend data(invert-$x) $pair2 $pair1
    }
    method X-disconnect {x pair1 pair2} {
	if { ! [dict exists $data($x) $pair1]} { error "$x \"$pair1\" does not exist" }
	if { ! [dict exists $data($x) $pair2]} { error "$x \"$pair2\" does not exist" }
	if { ! [$self X-connected $x $pair1 $pair2]} { error "${x}s \"$pair1\" \"$pair2\" are not connected" }
	set list [dict get $data($x) $pair1]
	set i [lsearch -exact $list $pair2]
	dict set data($x) $pair1 [lreplace $list $i $i]
	set list [dict get $data(invert-$x) $pair2]
	set i [lsearch -exact $list $pair1]
	dict set data(invert-$x) $pair2 [lreplace $list $i $i]
    }
    method X-connections-from {x pair} { return [$self X-get $x $pair] }
    method X-connections-to {x pair} { return [$self X-get invert-$x $pair] }
    
}


