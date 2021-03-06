#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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

package provide sdrtk::goertzel-graph 1.0.0

package require Tk
package require snit
package require sdrtk::graph

#
# build a graphical widget which displays the keying on a midi channel
# and the response of a Goertzel filter to the keyed tone
#
# a little useless in the end, but it did sort out some issues
#
snit::widgetadaptor sdrtk::goertzel-graph {
    option -atap1 -default {} -configuremethod Configure
    option -atap2 -default {} -configuremethod Configure
    option -mtap1 -default {} -configuremethod Configure
    option -mtap2 -default {} -configuremethod Configure
    option -meter1 -default {} -configuremethod Configure
    option -meter2 -default {} -configuremethod Configure
    delegate option * to hull
    delegate method * to hull

    variable data -array {
	input {}
	timeout 50
	first-frame {}
    }
    
    constructor {args} {
	installhull using sdrtk::graph -background white
	$self configure {*}$args
	after $data(timeout) [mymethod poll]
    }
    
    method exposed-options {} { return {-atap1 -atap2 -mtap1 -mtap2 -meter1 -meter2} }
    method {info-option -atap1} {} { return {audio tap name} }
    method {info-option -atap2} {} { return {audio tap name} }
    method {info-option -mtap1} {} { return {midi tap name} }
    method {info-option -mtap2} {} { return {midi tap name} }
    method {info-option -meter1} {} { return {meter tap name} }
    method {info-option -meter2} {} { return {meter tap name} }

    method poll {} {
	foreach opt {-atap1 -atap2 -mtap1 -mtap2} {
	    if {$options($opt) ne {}} { 
		if { ! [catch {$options($opt) get} get]} {
		    lappend data(input) $opt $get
		} else {
		    error "sdrtk::goertzel: $options($opt) get threw $get"
		}
	    }
	}
	if {$data(input) ne {}} { after idle [mymethod process] }
	after $data(timeout) [mymethod poll]
    }

    method process {} {
	# puts "sdrtk::goertzel process called with [llength $data(input)] items queued"
	set input $data(input)
	set data(input) {}
	foreach {opt get} $input {
	    set tag [list [llength $get] $opt]
	    switch -glob $tag {
		{0 -*} continue
		{* -meter*} {
		}
		{* -atap*} {
		}
		{* -mtap*} {
		    foreach item $get {
			foreach {frame bytes} $item break
			if {$data(first-frame) eq {}} { set data(first-frame) $frame }
			incr frame -$data(first-frame)
			if {[binary scan $bytes ccc cmd note vel] != 3} continue
			$self extend l$opt-$note $frame [expr {!$vel}] $frame $vel
			#puts "$opt $frame $cmd $note $vel"
		    }
		}
		default {
		    puts "sdrtk::goertzel process switch $tag not caught"
		}
	    }
	}
    }
    
    method extend {line args} {
	if { ! [$win line exists $line]} {
	    $win add line $line
	}
	$win line add point $line {*}$args
	if {0} {
	    
	    # check
	    set pts [$win line points $line]
	    set xmax [set xmin [lindex $pts 0]]
	    set ymax [set ymin [lindex $pts 1]]
	    foreach {x y} $pts {
		set xmin [tcl::mathfunc::min $xmin $x]
		set xmax [tcl::mathfunc::max $xmax $x]
		set ymin [tcl::mathfunc::min $ymin $y]
		set ymax [tcl::mathfunc::max $ymax $y]
	    }
	    puts "$xmin $ymin $xmax $ymax [$win line bbox $line]"
	}
    }

    method rescale {wd ht} {
    }

    method Configure {opt value} { 
	switch -- $opt {
	    -atap1 -
	    -atap2 -
	    -mtap1 -
	    -mtap2 -
	    -meter1 -
	    -meter2 {
		if {[catch {$value get} get]} {
		    if {$get eq "midi-tap $value is not running"} {
			$value start
			return [$self Configure $opt $value]
		    }
		    error "$value get threw $get"
		}
	    }
	}
	set options($opt) $value
    }
}
