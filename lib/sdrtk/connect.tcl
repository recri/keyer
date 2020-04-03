#!/usr/bin/tclsh
# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA
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
# [ ] produce a canvas with nodes representing clients of jackd
#	and lines representing connections between nodes
# [ ] interface with live jack sessions and modify them
#	produce scripts to recreate connections
# [ ] read and produce qjackctl patchbay descriptions?
# [x] jack list-ports connections get listed in both directions
#	ie forwards from outputs and backwards into inputs.
# [x] nodes correspond to jack clients, their client name, 
#	or client alias, is their identifier but that won't work
#	inside canvas, so create a unique tag for each node, port, 
#	and edge
# [x] put inputs to left, outputs to right
# [x] double click on node title to hide/show inputs and outputs
# [x] grab node to drag it
# [ ] click select node for making connection
# [x] normally show nodes as node labels only, ports hidden
# [ ] distinguish sample and event streams by color? texture?
# [ ] make connections between nodes in the obvious way if possible
# [ ] pop up choices where obvious is ambiguous
# [x] system:input node separate from system:output node
# [ ] dang, the node-tag depends on the order, so if a node changes order
#	it changes tag and it won't persist in location, but making a persistent
#	tag breaks the tag-name hack.
# [ ] need a block select or multiselect
# [ ] node port attachments collapsed/expanded
# [ ] port connections collapsed/expanded
# [ ] automatic layout
# [ ] connection hints from setups
# [ ] clustering hints from setups
# [ ] save/restore layouts
# [ ] add optional nodes/ports/connections, ala patchbay
#
#  { "sample-rate",_sample_rate, "get the jack server sample rate" },
#  { "buffer-size",_buffer_size, "get the jack server buffer size" },
#  { "cpu-load", _cpu_load,      "get the jack server cpu load percent" },
#  { "is-realtime",_is_realtime, "get the jack server realtime status" },
#  { "frame-time", _frame_time,  "get the jack server approximate frame time" },
#  { "time", _time,	        "get the jack server time in microseconds?" },
#  { "version", _version,        "get the jack server version" },
#  { "version-string", _version_string, "get the jack server version string" },
#  { "client-name-size", _client_name_size, "get the jack server client name size" },
#  { "port-name-size", _port_name_size, "get the jack server port name size" },
#  { "port-type-size", _port_type_size, "get the jack server port type size" },
#  { "time-to-frames", _time_to_frames, "ask the jack server to convert time to frames" },
#  { "frames-to-time", _frames_to_time, "ask the jack server to convert frames to time" },
#  { "list-ports", _list_ports,  "get a list of the ports open on the jack server" },
#  { "connect", _connect,        "connect ports on the jack server" },
#  { "disconnect", _disconnect,  "disconnect ports on the jack server" },
#

package provide sdrtk::connect 0.1

package require Tk
package require snit
package require sdrtcl::jack

namespace eval sdrtk {}

snit::type sdrtk::graph {
    variable d -array { tags {} nodes {} ports {} edges {} }

    constructor {args} { $self graph-init }

    method graph-init {} { array set d [list tags [dict create] nodes [dict create] ports [dict create] edges [dict create]] }
    
    proc make-tag {x} { 
	binary scan $x c* bytes
	set hash 0
	foreach byte $bytes { set hash [expr {($hash<<1)+$byte}] }
	return $hash
    }

    method make-node {name args} { 
	set tag node-[make-tag $name]
	dict set d(nodes) $name [dict create name $name label $name tag $tag \
				     n-port 0 ports {} \
				     n-input 0 input-ports {} \
				     n-output 0 output-ports {} \
				     from-edges {} to-edges {} \
				     max-input-width 0 \
				     max-output-width 0 \
				     {*}$args]
	dict set d(tags) $tag $name
    }
    method nodes {} { return [dict keys $d(nodes)] }
    method node-exists {name} { return [dict exists $d(nodes) $name] }
    method node-get {name} { return [dict get $d(nodes) $name] }
    method node-set {name value} { dict set d(nodes) $name $value }
    method node-lappend {n key item} {
	set vals [$self node-get $n]
	dict lappend vals $key $item
	$self node-set $n $vals
    }
    method node-incr {n key {item 1}} {
	set vals [$self node-get $n]
	dict incr vals $key $item
	$self node-set $n $vals
    }
    method node-max {n key item} {
	set vals [$self node-get $n]
	dict set vals $key [tcl::mathfunc::max [dict get $vals $key] $item]
	$self node-set $n $vals
    }
    method node-name {n} { return [dict get $d(nodes) $n name] }
    method node-tag {n} { return [dict get $d(nodes) $n tag] }
    method node-ports {n} { return [dict get $d(nodes) $n ports] }
    method node-input-ports {n} { return [dict get $d(nodes) $n input-ports] }
    method node-output-ports {n} { return [dict get $d(nodes) $n output-ports] }
    method node-n-port {n} { return [dict get $d(nodes) $n n-port] }
    method node-n-input {n} { return [dict get $d(nodes) $n n-input] }
    method node-n-output {n} { return [dict get $d(nodes) $n n-output] }
    method node-max-input-width {n} { return [dict get $d(nodes) $n max-input-width] }
    method node-max-output-width {n} { return [dict get $d(nodes) $n max-output-width] }
    method node-width {n} { return [dict get $d(nodes) $n width] }
    method node-label {n} { return [dict get $d(nodes) $n label] }
    method node-expand {n} { return [dict get $d(nodes) $n expand] }
    method node-input-attach {n} { return [dict get $d(nodes) $n input-attach] }
    method node-output-attach {n} { return [dict get $d(nodes) $n output-attach] }
    method node-to-edges {n} { return [dict get $d(nodes) $n to-edges] }
    method node-from-edges {n} { return [dict get $d(nodes) $n from-edges] }

    method node-set-width {n w} { dict set d(nodes) $n width $w }
    method node-set-expand {n e} { dict set d(nodes) $n expand $e }
    method node-set-input-attach {n args} { dict set d(nodes) $n input-attach $args }
    method node-set-output-attach {n args} { dict set d(nodes) $n output-attach $args }

    method node-padded-label {n expand} {
	set width [$self node-width $n]
	set text [$self node-label $n]
	while {[string length $text] < $width-2} { set text " $text " }
	if {[$self node-n-input $n] && ! $expand} { set text "\u25b6$text" } else { set text " $text" }
	if {[$self node-n-output $n] && ! $expand} { set text "$text\u25b6" } else { set text "$text " }
	return $text
    }
    method node-add-port {n p} {
	set dir [$self port-direction $p]
	$self node-lappend $n ports $p
	$self node-lappend $n $dir-ports $p
	$self node-incr $n n-port
	$self node-incr $n n-$dir
	$self node-max $n max-$dir-width [string length [$self port-pname $p]]
	set iw [$self node-max-input-width $n]
	set ow [$self node-max-output-width $n]
	$self node-set-width $n [expr {max([string length $n]+2+2, ($iw>0?$iw+3:0)+($ow>0?$ow+3:0))}]
    }

    method make-port {name args} { 
	set tag port-[make-tag $name]
	dict set d(ports) $name [dict create name $name tag $tag edges {} {*}$args]
	dict set d(tags) $tag $name
	$self node-add-port [$self port-node $name] $name
    }
    method ports {} { return [dict keys $d(ports)] }
    method port-exists {name} { return [dict exists $d(ports) $name] }
    method port-get {name} { return [dict get $d(ports) $name] }
    method port-set {name value} { dict set d(ports) $name $value }
    method port-name {p} { return [dict get $d(ports) $p name] }
    method port-node {p} { return [dict get $d(ports) $p node] }
    method port-pname {p} { return [dict get $d(ports) $p pname] }
    method port-direction {p} { return [dict get $d(ports) $p direction] }
    method port-type {p} { return [dict get $d(ports) $p type] }
    method port-physical {p} { return [dict get $d(ports) $p physical] }
    method port-connections {p} { return [dict get $d(ports) $p connections] }
    method port-tag {p} { return [dict get $d(ports) $p tag] }

    method port-input-attach {p} { return [dict get $d(ports) $p input-attach] }
    method port-output-attach {p} { return [dict get $d(ports) $p output-attach] }
    method port-set-input-attach {p args} { dict set d(ports) $p input-attach $args }
    method port-set-output-attach {p args} { dict set d(ports) $p output-attach $args }

    method port-lappend {p key item} {
	set dict [$self port-get $p]
	dict lappend $dict $key $item
	$self port-set $p $dict
    }
	
    method port-add-edge {p edge} { 
	$self port-lappend $p edges $edge 
	if {[$self port-direction $p] eq {input}} {
	    $self node-lappend [$self port-node $p] to-edges $edge
	} else {
	    $self node-lappend [$self port-node $p] from-edges $edge
	}
    }
    method port-edges {p} { return [dict get $d(ports) $p edges] }

    method make-edge {name args} { 
	set tag edge-[make-tag $name]
	dict set d(edges) $name [dict create name $name tag $tag {*}$args]
	dict set d(tags) $tag $name
	$self port-add-edge [$self edge-from $name] $name
	$self port-add-edge [$self edge-to $name] $name
    }
    method edges {} { return [dict keys $d(edges)] }
    method edge-exists {name} { return [dict exists $d(edges) $name] }
    method edge-get {name} { return [dict get $d(edges) $name] }
    method edge-name {e} { return [dict get $d(edges) $e name] }
    method edge-from {e} { return [dict get $d(edges) $e from] }
    method edge-to {e} { return [dict get $d(edges) $e to] }
    method edge-tag {e} { return [dict get $d(edges) $e tag] }

    method tag-name {tag} { return [dict get $d(tags) $tag] }

    # it's convenient for layout 
    # if the system:capture* ports are on a different
    # node than the system:playback* ports, so we make
    # make capture and playback nodes but label them both
    # as system
    method port-normalize {port} {
	switch -glob $port {
	    system:*capture* { regsub system: $port capture: port }
	    system:*playback* { regsub system: $port playback: port }
	    system:* { error "unmatched system port: $port" }
	    default { }
	}
	return $port
    }

}

snit::widget sdrtk::connect {
    option -server -default {} -readonly 1
    component network
    component graph
    variable data -array {
	drag {}
    }

    constructor {args} {
	install network using canvas $win.network -bg white
	install graph using sdrtk::graph $self.graph
	
	pack $network -side top -fill both -expand true
	pack [ttk::frame $win.buttons] -side top -fill x
	foreach button {refresh collapse-all expand-all layout} {
	    pack [ttk::button $win.buttons.$button -text $button -command [mymethod $button]] -side left -anchor w
	}
	bind $network <Double-1> [mymethod double-click %x %y]
	bind $network <ButtonPress-1> [mymethod drag-select %x %y]
	bind $network <ButtonPress-3> [mymethod push-start %x %y]
	bind $network <MouseWheel> [mymethod mouse-wheel %D]
    }

    method mouse-wheel {delta} { puts "mouse-wheel $delta" }

    # node expand/collapse
    method double-click {x y} {
	set tag [lindex [$network gettags [$network find withtag current]] 0]
	if {[string match node-* $tag]} { $self client-toggle [$self tag-name $tag] }
    }

    # node dragging
    method drag-select {x y} {
	set current [$network find withtag current]
	if {$current eq {}} return
	set tag [lindex [$network gettags $current] 0]
	if {$tag eq {}} return
	if { ! [string match node-* $tag]} return
	$network raise $tag
	set data(drag) [dict create x $x y $y n [$self tag-name $tag]]
	bind $network <Motion> [mymethod drag %x %y]
	bind $network <ButtonRelease-1> [mymethod drag-drop %x %y]
    }
    method drag {x y} {
	set dx [expr {$x-[dict get $data(drag) x]}]
	set dy [expr {$y-[dict get $data(drag) y]}]
	$self client-displace [dict get $data(drag) n] [list $dx $dy]
	# $network move [dict get $data(drag) t] $dx $dy
	dict set data(drag) x $x
	dict set data(drag) y $y
    }
    method drag-drop {x y} {
	bind $network <Motion> {}
	bind $network <ButtonRelease-1> {}
    }

    # canvas scanning, better with scrollwheel, need scrollregion
    method push-start {x y} {
	$network scan mark $x $y
	bind $network <Motion> [mymethod push %x %y]
	bind $network <ButtonRelease-3> [mymethod push-drop %x %y]
    }
    method push {x y} {
	$network scan dragto $x $y
    }
    method push-drop {x y} {
	bind $network <Motion> {}
	bind $network <ButtonRelease-3> {}
    }
    
    # content
    method client-draw {node} {
	set expand  [$self node-expand $node]
	set tag [$self node-tag $node]
	set font {Courier 10}

	$network create rect 0 0 1 1 -fill lightgrey -outline black -tag [list $tag $tag-box]

	set text [$self node-padded-label $node $expand]
    
	$network create text 0 0 -text $text -tag [list $tag $tag-label] -anchor n -font $font
	
	foreach {x0 y0 x1 y1} [$network bbox $tag-label] break
	$self node-set-input-attach $node $x0 [expr {($y0+$y1)/2.0}]
	$self node-set-output-attach $node $x1 [expr {($y0+$y1)/2.0}]

	if {$expand} {
	    foreach {x0 y0 x1 y1} [$network bbox $tag-label] break
	    foreach port [$self node-input-ports $node] {
		set text "\u25b6 [$self port-pname $port] "
		set ptag [$self port-tag $port]
		$network create text $x0 $y1 -text $text -tag [list $tag $ptag $tag-input-port] -anchor nw -font $font
		foreach {x0 y0 x1 y1} [$network bbox $ptag] break
		$self port-set-input-attach $port $x0 [expr {($y0+$y1)/2.0}]
	    }
	
	    foreach {x0 y0 x1 y1} [$network bbox $tag-label] break
	    foreach port [$self node-output-ports $node] {
		set text " [$self port-pname $port] \u25b6"
		set ptag [$self port-tag $port]
		$network create text $x1 $y1 -text $text -tag [list $tag $ptag $tag-output-port] -anchor ne -font $font
		foreach {x0 y0 x1 y1} [$network bbox $ptag] break
		$self port-set-output-attach $port $x1 [expr {($y0+$y1)/2.0}]
	    }
	}

	$network coords $tag-box [$network bbox $tag]
    }

    method connection-draw {edge} {
	set fport [$self edge-from $edge]
	set tport [$self edge-to $edge]
	set fnode [$self port-node $fport]
	set tnode [$self port-node $tport]
	#puts "$fport -> [$self port-get $fport]"
	#puts "$tport -> [$self port-get $tport]"
	#puts "$fnode -> [$self node-get $fnode]"
	#puts "$tnode -> [$self node-get $tnode]"
	if {[$self node-expand $fnode]} {
	    set origin [$self port-output-attach $fport]
	} else {
	    set origin [$self node-output-attach $fnode]
	}
	if {[$self node-expand $tnode]} {
	    set dest [$self port-input-attach $tport]
	} else {
	    set dest [$self node-input-attach $tnode]
	}
	$network delete [$self edge-tag $edge]
	foreach {x y} $origin break; set dorigin [list [expr {$x+5}] $y]
	foreach {x y} $dest break; set ddest [list [expr {$x-5}] $y]
	$network create line {*}$origin {*}$dorigin {*}$ddest {*}$dest -smooth true -splinesteps 10 -tag [$self edge-tag $edge]
	# $network create line {*}$origin {*}$dest -smooth true -splinesteps 10 -arrow last -tag [$self edge-tag $edge]
	$network lower [$self edge-tag $edge]
    }

    method client-get-coords {node} {
	return [$network coords [$self node-tag $node]-label]
    }

    method client-set-coords {node newcoords} {
	if {$newcoords eq {}} { error "client-set-coords $node {$newcoords}: no new coords?" }
	set oldcoords [$self client-get-coords $node]
	if {$oldcoords eq {}} { error "client-set-coords $node {$oldcoords}: no old coords?" }
	set delta [lmap o $oldcoords n $newcoords {expr {$n-$o}}]
	$network move [$self node-tag $node] {*}$delta
    }
    method client-displace {node delta} {
	# move the node
	$network move [$self node-tag $node] {*}$delta

	# update input attachment points
	if {[$self node-n-input $node] > 0} {
	    #puts "client-displace $node $delta : node-input-attach [$self node-input-attach $node]"
	    $self node-set-input-attach $node {*}[lmap o [$self node-input-attach $node] d $delta {expr {$o+$d}}]
	    if {[$self node-expand $node]} {
		foreach port [$self node-input-ports $node] {
		    #puts "client-displace $node $delta : port-input-attach [$self port-input-attach $port]"
		    $self port-set-input-attach $port {*}[lmap o [$self port-input-attach $port] d $delta {expr {$o+$d}}]
		}
	    }
	    foreach edge [$self node-to-edges $node] {
		#puts "client-displace $node $delta : connection-draw $edge"
		$self connection-draw $edge
	    }
	}

	# update output attachment points
	if {[$self node-n-output $node] > 0} {
	    #puts "client-displace $node $delta : node-output-attach [$self node-output-attach $node]"
	    $self node-set-output-attach $node {*}[lmap o [$self node-output-attach $node] d $delta {expr {$o+$d}}]
	    if {[$self node-expand $node]} {
		foreach port [$self node-output-ports $node] {
		    # puts "client-displace $node $delta : port-output-attach [$self port-output-attach $port]"
		    $self port-set-output-attach $port {*}[lmap o [$self port-output-attach $port] d $delta {expr {$o+$d}}]
		}
	    }
	    foreach edge [$self node-from-edges $node] {
		#puts "client-displace $node $delta : connection-draw $edge"
		$self connection-draw $edge
	    }
	}
    }
    method client-move-to {node newcoords} {
	# move the client and its attached connections
	$self client-displace $node [lmap o [$self client-get-coords $node] n $newcoords {expr {$n-$o}}]
    }
    method client-redraw {node} {
	set tag [$self node-tag $node]
	set coords [$self client-get-coords $node]
	$network delete $tag
	$self client-draw $node
	$self client-move-to $node $coords
    }

    method client-expand {node} {   $self node-set-expand $node 1; $self client-redraw $node }
    method client-collapse {node} { $self node-set-expand $node 0; $self client-redraw $node }
    method client-toggle {node} {   $self node-set-expand $node [expr { ! [$self node-expand $node] }]; $self client-redraw $node }

    method refresh {} {
	# preserve coordinates and expand
	set coords {}
	set expand {}
	foreach node [$self nodes] {
	    lappend coords $node [$self client-get-coords $node]
	    lappend expand $node [$self node-expand $node]
	}
	
	# clear the decks
	$self graph-init
	$network delete all

	# parse the current set of ports
	dict for {port desc} [sdrtcl::jack list-ports] {
	    set port [$self port-normalize $port]
	    dict set desc connections [lmap c [dict get $desc connections] {$self port-normalize $c}]
	    foreach {cname pname} [split $port :] break
	    if { ! [$self node-exists $cname]} { 
		set args [list $cname name $cname label $cname expand 0]
		if {$cname in {capture playback}} { lappend args label system }
		if {[dict exists $expand $cname]} { lappend args expand [dict get $expand $cname] }
		$self make-node {*}$args
	    }
	    if { ! [$self port-exists $port]} {
		$self make-port $port name $port node $cname pname $pname {*}$desc
	    } else {
		error "duplicate port $port"
	    }
	}

	# parse the port connections into the directed edges
	foreach port [$self ports] {
	    if {[$self port-direction $port] eq {output}} {
		foreach nbr [$self port-normalize [$self port-connections $port]] {
		    if {[$self port-direction $nbr] eq {input}} {
			set e [list $port $nbr]
			$self make-edge $e name $e from $port to $nbr
		    }
		}
	    }
	}
	
	# draw the nodes
	foreach node [$self nodes] { 
	    $self client-draw $node
	}
	# draw the edges
	foreach edge [$self edges] {
	    $self connection-draw $edge
	}

	# move them into position
	foreach node [$self nodes] {
	    if {[dict exists $coords $node]} {
		$self client-move-to $node [dict get $coords $node]
	    } else {
		$self client-move-to $node [list [expr {int(400*rand())}] [expr {int(400*rand())}]]
	    }
	}

	# run tests
	$self test
    }

    method collapse-all {} { foreach node [$self nodes] { $self client-collapse $node } }
    method expand-all {} { foreach node [$self nodes]  { $self client-expand $node } }
    
    method layout {} {
	set nodes {}
	set dot {}
	append dot "digraph {"
	# ,rotate="90"
	# ,rankdir=[LR|RL|TB]
	# ,center=1
	append dot { graph [rankdir="LR",center=1,margin=1,size="6,6"];}
	foreach node [$self nodes] {
	    set nodes {}
	    append dot " $node \[shape=box,label=\"  [$self node-padded-label $node 0]  \"\];"
	    foreach port [$self node-output-ports $node] {
		foreach conn [$self port-connections $port] {
		    set node2 [$self port-node $conn]
		    if {$node2 ni $nodes} {
			lappend nodes $node2
			append dot " $node -> $node2;"
		    }
		}
	    }
	}
	append dot " }"
	set result [exec echo "$dot" | dot]
	regsub -all \\\[ $result \{ result
	regsub -all \\\] $result \} result
	regsub -all {,\n[ \t]+} $result { } result
	regsub -all \; $result {} result
	regsub -all = $result { } result
	regsub -all {([^ \t\n]+ -> [^ \t\n]+)} $result {{\1}} result
	set digraph [dict get $result digraph]
	dict for {key val} [dict get $result digraph] {
	    if {[$self node-exists $key]} { 
		$self client-move-to $key [split [dict get $val pos] ,]
	    }
	}
    }
    
    # graph methods
    delegate method * to graph

    method test {} {
	# verify tag names
	foreach name [$self nodes] { 
	    if {[$self tag-name [$self node-tag $name]] ne $name} {
		error "tag-name check failed for $name and [$self node-tag $name] and [$self tag-name [$self node-tag $name]]" 
	    }
	}
	foreach name [$self ports] { 
	    if {[$self tag-name [$self port-tag $name]] ne $name} {
		error "tag-name check failed for $name and [$self port-tag $name] and [$self tag-name [$self port-tag $name]]" 
	    }
	}
	foreach name [$self edges] { 
	    if {[$self tag-name [$self edge-tag $name]] ne $name} {
		error "tag-name check failed for $name and [$self edge-tag $name] and [$self tag-name [$self edge-tag $name]]" 
	    }
	}
	# verify input and output ports
	foreach name [$self nodes] {
	    if {[$self node-input-ports $name] ne [lmap p [$self node-ports $name] {expr {([$self port-direction $p] eq {input}) ? $p : [continue]}}]} {
		error "input-ports check failed for $name"
	    }
	    if {[$self node-output-ports $name] ne [lmap p [$self node-ports $name] {expr {([$self port-direction $p] eq {output}) ? $p : [continue]}}]} {
		error "output-ports check failed for $name"
	    }
	}
    }
    
}
