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

package provide sdrctl::controller 1.0.0

package require snit

package require sdrtype::types

##
## the host which all the wrapped controls register with and use as
## to hook themselves up to each other.
##

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
    method part-filter-pred {glob pred} { return [$self X-filter-pred part $glob $pred] }

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

    # this is hacky, finding the corresponding port leaving the other side of a jack component
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

    method part-rewrite-connections-to {part port candidates} { return [[$self part-get $part] rewrite-connections-to $port $candidates] }
    method part-rewrite-connections-from {part port candidates} { return [[$self part-get $part] rewrite-connections-from $port $candidates] }

    # chase each connections-to chain starting from {part port} until you find an active component
    # and return the list of {part port} pairs found.
    # this is looking up the sample computation graph at the inputs to port
    # todo - avoid chasing through all the disabled alternates in an alternates block
    method port-active-connections-to {pair} {
	set active {}
	set candidates [$self part-rewrite-connections-to {*}$pair [$self port-connections-to {*}$pair]]
	foreach source $candidates {
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

    # chase each connections-from chain starting from {part port} until you find an active component
    # and return the list of active {port part} pairs found
    # this is looking down the sample computation graph at the outputs from port
    # todo - avoid chasing through all the disabled alternates in an alternates block
    method port-active-connections-from {pair} {
	set active {}
	set candidates [$self part-rewrite-connections-from {*}$pair [$self port-connections-from {*}$pair]]
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
	# puts "activate tree $name"
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if { ! [$self part-is-enabled $name]} return

	# find the parts to activate
	set subtree [$self part-filter-pred $name* [mymethod part-is-enabled]]

	# activate the parts
	foreach part $subtree {
	    # puts "activate $part"
	    $self part-configure $part -activate true
	}
	    
	# find the connections to make
	set subgraph [dict create]
	foreach part $subtree {
	    if {[$self part-type $part] ni {jack hw}} continue
	    #puts "activate ports $part"
	    foreach port [$self part-ports $part] {
		set pair [list $part $port]
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
	if { ! [$self part-is-active $name]} { error "part \"$name\" is not active" }

	# find the set to deactivate
	set subtree [$self part-filter-pred $name* [mymethod part-is-active]]

	# find the connections to break
	set subgraph [dict create]
	foreach part $subtree {
	    if {[$self part-type $part] ni {jack hw}} continue
	    foreach port [$self part-ports $part] {
		set pair [list $part $port]
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
	foreach port [$self part-ports $name] {
	    # puts "part-activate-node $name port $port"
	    set pair [list $name $port]
	    set jackport [join $pair :]
	    # find the connections from node
	    set from($port) {}
	    foreach sink [$self port-active-connections-from $pair] {
		set connection [list $jackport [join $sink :]]
		if {[lsearch -exact $from($port) $connection] < 0} {
		    # puts "add connect $connection"
		    lappend from($port) $connection
		    lappend makes $connection
		}
	    }
	    # find the connections to node
	    set to($port) {}
	    foreach source [$self port-active-connections-to $pair] {
		set connection [list [join $source :] $jackport]
		if {[lsearch -exact $to($port) $connection] < 0} {
		    # puts "add connect $connection"
		    lappend to($port) $connection
		    lappend makes $connection
		}
	    }
	    # in ports will have connections-to but no connections-from
	    # out ports will have connections-from but no connections-to
	    # the short circuit connections will match the source of the in port connections-to
	    # with the sinks of the out port connections from
	    if {$from($port) ne {} && $to($port) ne {}} {
		error "activating $pair finds connections both ways"
	    }
	}
	# that found the makes, and left the per port information in to and from
	# now match the non-empty to's to the non-empty from's to generate the
	# break list
	foreach to_port [array names to] {
	    if {$to($to_port) ne {}} {
		set from_port [complement $to_port]
		foreach to_conn $to($to_port) {
		    lassign $to_conn to_source to_me
		    foreach from_conn $from($from_port) {
			lassign $from_conn from_me from_sink
			lappend breaks [list $to_source $from_sink]
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
    
    method part-enable {name} {
	if {[$self part-is-enabled $name]} { error "part \"$name\" is enabled" }
	$self part-configure $name -enable true
	if {[$self part-is-active [$self part-container $name]]} {
	    $self part-activate-node $name
	}
    }
    method part-disable {name} {
	if { ! [$self part-is-enabled $name]} { error "part \"$name\" is not enabled" }
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


