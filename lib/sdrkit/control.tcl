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
# there is one sdrkit::control in an application
# containing one or more sdrkit::component's.
# the control allows components to register
# their presence,
# their dsp sample stream connectivity,
# their interest in values for options,
# and their abilities to supply values for options.
#

package provide sdrkit::control 1.0.0

package require snit
package require sdrkit
package require sdrkit::comm
package require sdrtcl::jack

namespace eval sdrkit {}

snit::type sdrkit::control {
    option -notifier {}
    option -server default
    
    variable data -array {}
    
    constructor {args} {
	set data(part) [dict create]
	set data(opt) [dict create]
	set data(invert-opt) [dict create]
	set data(port) [dict create]
	set data(invert-port) [dict create]
	$self configure {*}$args
    }
    ## return the controller
    method controller {} { return [sdrkit::comm::wrap $self] }
    ## call all the resolve methods
    method resolve {} {
	foreach part [$self part-list] {
	    {*}[$self part-get $part] resolve
	}
    }
    
    ## part methods
    ## parts are components in the computation which supply
    ## opts and ports that can be wired up
    method part-call {name args} { return [sdrkit::comm::send [$self part-get $name] {*}$args] }
    method part-exists {name} { return [$self X-exists part $name] }
    method part-get {name} { return [$self X-get part $name] }
    method part-add {name args} {
	$self X-add part $name
	dict set data(part) $name $args
	foreach opt [$self part-options $name] { $self opt-add [list $name $opt] }
	foreach port [$self part-in-ports $name] { $self port-add [list $name $port] }
	foreach port [$self part-out-ports $name] { $self port-add-if-new [list $name $port] }	
	return {}
    }
    method part-remove {name} {
	#puts "part-remove $name"
	if { ! [$self part-exists $name]} { error "part \"$name\" does not exist" }
	#if {[$self part-is-active $name]} { $self part-deactivate }
	#if {[$self part-is-enabled $name]} { $self part-disable }
	foreach pair [$self opt-filter [list $name *]] { $self opt-remove $pair }
	foreach pair [$self port-filter [list $name *]] { $self port-remove $pair }
	$self X-remove part $name
	return {}
    }
    method part-destroy {name} { return [$self part-call $name destroy] }
    method part-list {} { return [$self X-list part] }
    method part-filter {glob} { return [$self X-filter part $glob] }
    method part-filter-pred {glob pred} { return [$self X-filter-pred part $glob $pred] }

    method part-configure {name args} {
	if {$options(-notifier) ne {}} { {*}$options(-notifier) $name {*}$args }
	return [$self part-call $name configure {*}$args]
    }
    method part-cget {name opt} { return [$self part-call $name cget $opt] }

    method part-container {name} {
	set container [$self part-cget $name -container]
	if {$container eq {}} {
	    return {}
	} else {
	    return [$container cget -name]
	}
    }
    method part-options {name} { return [$self part-cget $name -options] }
    method part-in-ports {name} { return [$self part-cget $name -in-ports] }
    method part-out-ports {name} { return [$self part-cget $name -out-ports] }
    method part-type {name} { return [$self part-cget $name -type] }
    method part-is-enabled {name} { return [$self part-cget $name -enable] }
    method part-is-active {name} { return [$self part-cget $name -activate] }
    method part-enable {name} {
	if {[$self part-is-enabled $name]} { error "part \"$name\" is enabled" }
	$self part-configure $name -enable true
	if {[$self part-container $name] ne {} && [$self part-is-active [$self part-container $name]]} {
	    $self part-activate-node $name
	}
    }
    method part-disable {name} {
	if { ! [$self part-is-enabled $name]} { error "part \"$name\" is not enabled" }
	if {[$self part-is-active $name]} { $self part-deactivate-node $name }
	$self part-configure $name -enable false
    }
    method part-activate {name} {
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if { ! [$self part-is-enabled $name]} { error "part \"$name\" is not enabled, cannot activate" }
	$self part-activate-tree $name
    }
    method part-deactivate {name} {
	if { ! [$self part-is-active $name]} { error "part \"$name\" is not active" }
	$self part-deactivate-tree $name
    }

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


    method part-port-complement {part port} { return [[$self part-get $part] port-complement $port] }

    method pair-complement {pair} {
	set port [$self part-port-complement {*}$pair]
	if {$port eq {}} {
	    return {}
	}
	return [list [lindex $pair 0] $port]
    }

    method part-rewrite-connections-to {part port candidates} { return [[$self part-get $part] rewrite-connections-to $port $candidates] }
    method part-rewrite-connections-from {part port candidates} { return [[$self part-get $part] rewrite-connections-from $port $candidates] }

    # chase each connections-to chain starting from {part port} until you find an active component
    # and return the list of {part port} pairs found.
    # this is looking up the sample computation graph at the inputs to port
    # todo - avoid chasing through all the disabled alternates in an alternates block
    method port-active-connections-to {pair} {
	set active {}
	set candidates [$self part-rewrite-connections-to {*}$pair [$self port-connections-to $pair]]
	# puts "port-active-connections-to: $pair candidates={$candidates}"
	foreach source $candidates {
	    lassign $source part port
	    set type [$self part-type $part]
	    if {$type in {jack physical}} {
		if {[$self part-is-active $part]} {
		    # puts "port-active-connections-to: $pair accepted source={$source}"
		    lappend active $source
		} elseif {$type eq {jack}} {
		    set source [$self pair-complement $source]
		    # puts "port-active-connections-to: $pair searching source={$source}"
		    if {$source ne {}} {
			lappend active {*}[$self port-active-connections-to $source]
		    }
		}
	    } else {
		# puts "port-active-connections-to: $pair searching source={$source}"
		lappend active {*}[$self port-active-connections-to $source]
	    }
	}
	# puts "port-active-connections-to: $pair candidates={$candidates} -> {$active}"
	return $active
    }

    # chase each connections-from chain starting from {part port} until you find an active component
    # and return the list of active {port part} pairs found
    # this is looking down the sample computation graph at the outputs from port
    method port-active-connections-from {pair} {
	set active {}
	set candidates [$self part-rewrite-connections-from {*}$pair [$self port-connections-from $pair]]
	foreach sink [$self port-connections-from $pair] {
	    lassign $sink part port
	    set type [$self part-type $part]
	    if {$type in {jack physical}} {
		if {[$self part-is-active $part]} {
		    #puts "port-active-connections-from: $pair accepted sink={$sink}"
		    lappend active $sink
		} elseif {$type eq {jack}} {
		    set sink [$self pair-complement $sink]
		    #puts "port-active-connections-from: $pair searching sink={$sink}"
		    if {$sink ne {}} {
			lappend active {*}[$self port-active-connections-from $sink]
		    }
		}
	    } else {
		#puts "port-active-connections-from: $pair searching sink={$sink}"
		lappend active {*}[$self port-active-connections-from $sink]
	    }
	}
	return $active
    }

    method part-activate-tree {name} {
	# find the parts to activate
	set subtree [$self part-filter-pred $name* [mymethod part-is-enabled]]

	# activate the parts
	foreach part $subtree {
	    #puts "activate $part"
	    $self part-configure $part -activate true
	}
	    
	# find the connections to make
	set subgraph [dict create]
	foreach part $subtree {
	    if {[$self part-type $part] ni {jack physical}} continue
	    #puts "activate ports $part"
	    foreach pair [$self port-filter [list $part *]] {
		foreach sink [$self port-active-connections-from $pair] {
		    dict set subgraph $pair $sink 1
		}
		foreach source [$self port-active-connections-to $pair] {
		    dict set subgraph $source $pair 1
		}
	    }
	}

	# now make the activated connections
	dict for {src dstdict} $subgraph {
	    foreach dst [dict keys $dstdict] {
		# puts "activate connect $src $dst"
		sdrtcl::jack -server $options(-server) connect [join $src :] [join $dst :]
	    }
	}
    }
    
    # deactivating a tree could be simpler, because all the jack connections just
    # go away as each node is deactivated, but we do it by hand
    method part-deactivate-tree {name} {

	# find the set to deactivate
	set subtree [$self part-filter-pred $name* [mymethod part-is-active]]

	# find the connections to break
	set subgraph [dict create]
	foreach part $subtree {
	    if {[$self part-type $part] ni {jack physical}} continue
	    foreach pair [$self port-filter [list $part *]] {
		foreach sink [$self port-active-connections-from $pair] {
		    dict set subgraph $pair $sink 1
		}
		foreach source [$self port-active-connections-to $pair] {
		    dict set subgraph $source $pair 1
		}
	    }
	}

	# break the active connections
	dict for {src dstdict} $subgraph {
	    foreach dst [dict keys $dstdict] {
		sdrtcl::jack -server $options(-server) disconnect [join $src :] [join $dst :]
	    }
	}

	# deactivate the nodes 
	foreach part $subtree { $self part-configure $part -activate false }
    }
    
    # activating a node needs to make the new connections before breaking the old
    # to keep the samples flowing without hiccups.

    method part-node-connections {name} {
	# find the connections which the node makes when activated, the makes,
	# and the connections which route around the node when deactivated, the breaks.
	# these cannot be cached because they depend on which neighbors are active.
	# both activate-node and deactivate-node use the same lists of connections
	# but in reverse senses
	# puts "part-node-connections $name"
	array set to {}
	array set from {}
	set makes {}
	set breaks {}
	foreach pair [$self port-filter [list $name *]] {
	    # puts "part-activate-node $pair"
	    set jackport [join $pair :]
	    # find the connections from node
	    set from($pair) {}
	    foreach sink [$self port-active-connections-from $pair] {
		set connection [list $jackport [join $sink :]]
		if {[lsearch -exact $from($pair) $connection] < 0} {
		    # puts "add connect $connection"
		    lappend from($pair) $connection
		    lappend makes $connection
		}
	    }
	    # find the connections to node
	    set to($pair) {}
	    foreach source [$self port-active-connections-to $pair] {
		set connection [list [join $source :] $jackport]
		if {[lsearch -exact $to($pair) $connection] < 0} {
		    # puts "add connect $connection"
		    lappend to($pair) $connection
		    lappend makes $connection
		}
	    }
	    # in ports will have connections-to but no connections-from
	    # out ports will have connections-from but no connections-to
	    # the short circuit connections will match the source of the in port connections-to
	    # with the sinks of the out port connections from
	    if {$from($pair) ne {} && $to($pair) ne {}} {
		error "activating $pair finds connections both ways"
	    }
	}
	# that found the makes, and left the per pair information in to and from
	# now match the non-empty to's to the non-empty from's to generate the
	# break list
	foreach to_pair [array names to] {
	    if {$to($to_pair) ne {}} {
		set from_pair [$self pair-complement $to_pair]
		if {$from_pair ne {}} {
		    foreach to_conn $to($to_pair) {
			lassign $to_conn to_source to_me
			foreach from_conn $from($from_pair) {
			    lassign $from_conn from_me from_sink
			    lappend breaks [list $to_source $from_sink]
			}
		    }
		}
	    }
	}
	# puts "part-node-connections $name: makes {$makes}"
	# puts "part-node-connections $name: breaks {$breaks}"
	return [list $makes $breaks]
    }

    method part-activate-node {name} {
	# puts "part-activate-node $name"
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if { ! [$self part-is-enabled $name]} return
	lassign [$self part-node-connections $name] makes breaks
	$self part-configure $name -activate true
	# puts "part-activate-node $name: makes={$makes}, breaks={$breaks}"
	foreach conn $makes { sdrtcl::jack -server $options(-server) connect {*}$conn }
	foreach conn $breaks { sdrtcl::jack -server $options(-server) disconnect {*}$conn }
    }
    
    method part-deactivate-node {name} {
	# puts "part-deactivate-node $name"
	if { ! [$self part-is-active $name]} { error "part \"$name\" is not active" }
	lassign [$self part-node-connections $name] breaks makes
	foreach conn $makes { sdrtcl::jack -server $options(-server) connect {*}$conn }
	foreach conn $breaks { sdrtcl::jack -server $options(-server) disconnect {*}$conn }
	$self part-configure $name -activate false
    }
    
    method part-report {name opt value args} {
	foreach pair [$self opt-connections-from [list $name $opt]] {
	    $self part-configure {*}$pair $value {*}$args
	}
    }
    
    ## opt methods
    ## opts are "configure options" in the tcl/tk sense which the components
    ## expose for connection to opts of other components
    method opt-exists {pair} { return [$self X-exists opt $pair] }
    method opt-connected {pair1 pair2} { return [$self X-connected opt $pair1 $pair2] }
    method opt-add {pair} { $self X-add opt $pair }
    method opt-add-if-new {pair} { if { ! [$self opt-exists $pair]} { $self X-add opt $pair } }
    method opt-remove {pair} { $self X-remove opt $pair} 
    method opt-connect {pair1 pair2} { $self X-connect opt $pair1 $pair2 }
    method opt-disconnect {pair1 pair2} { $self X-disconnect opt $pair1 $pair2 }
    method opt-list {} { return [$self X-list opt] }
    method opt-filter {glob} { return [$self X-filter opt $glob] }
    method opt-connections-to {pair} { return [$self X-connections-to opt $pair] }
    method opt-connections-from {pair} { return [$self X-connections-from opt $pair] }
    
    ## port methods
    ## ports are jack ports, both audio and midi, which the components
    ## expose for connection to ports of other components
    method port-exists {pair} { return [$self X-exists port $pair] }
    method port-connected {pair1 pair2} { return [$self X-connected port $pair1 $pair2] }
    method port-add {pair} { $self X-add port $pair }
    method port-add-if-new {pair} { if { ! [$self port-exists $pair]} { $self X-add port $pair } }
    method port-remove {pair} { $self X-remove port $pair }
    method port-connect {pair1 pair2} { $self X-connect port $pair1 $pair2 }
    method port-disconnect {pair1 pair2} { $self X-disconnect port $pair1 $pair2 }
    method port-list {} { return [$self X-list port] }
    method port-filter {glob} { return [$self X-filter port $glob] }
    method port-connections-to {pair} { return [$self X-connections-to port $pair] }
    method port-connections-from {pair} { return [$self X-connections-from port $pair] }
    
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
	return {}
    }
    method X-remove {x tag} {
	#puts "X-remove $x $tag"
	if { ! [dict exists $data($x) $tag]} { error "$x \"$tag\" does not exist" }
	if {$x in {opt port}} {
	    # remove the connections
	    foreach tag2 [dict get $data($x) $tag] {
		#puts "X-disconnect $x $tag $tag2"
		$self X-disconnect $x $tag $tag2
	    }
	    foreach tag2 [dict get $data(invert-$x) $tag] {
		#puts "X-disconnect $x $tag2 $tag"
		$self X-disconnect $x $tag2 $tag
	    }
	    dict unset data($x) $tag
	    dict unset data(invert-$x) $tag
	}
	# remove the tag
	dict unset data($x) $tag
	return {}
    }
    method X-list {x} { return [dict keys $data($x)] }
    method X-filter {x glob} { return [dict keys $data($x) $glob] }
    method X-filter-pred {x glob pred} {
	set list {}
	foreach y [dict keys $data($x) $glob] {
	    if {[{*}$pred $y]} {
		lappend list $y
	    }
	}
	return $list
    }
    method X-connected {x pair1 pair2} { return [expr {[lsearch -exact [dict get $data($x) $pair1] $pair2] >= 0}] }
    method X-connect {x pair1 pair2} {
	if { ! [dict exists $data($x) $pair1]} { error "$x \"$pair1\" does not exist" }
	if { ! [dict exists $data($x) $pair2]} { error "$x \"$pair2\" does not exist" }
	if {[$self X-connected $x $pair1 $pair2]} { error "${x}s \"$pair1\" \"$pair2\" are connected" }
	dict lappend data($x) $pair1 $pair2
	dict lappend data(invert-$x) $pair2 $pair1
	return {}
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
	return {}
    }
    method X-connections-from {x pair} { return [$self X-get $x $pair] }
    method X-connections-to {x pair} { return [$self X-get invert-$x $pair] }
    
}



