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
    option -filter1 -default {} -configuremethod Configure
    option -filter2 -default {} -configuremethod Configure
    option -filter3 -default {} -configuremethod Configure
    option -tap -default {} -configuremethod Configure
    delegate option * to hull
    delegate method * to hull

    variable data -array {
	input {}
	last-filter1 0
	last-filter2 0
	last-filter3 0
	timeout 50
	first-frame {}
    }
    
    constructor {args} {
	installhull using sdrtk::graph -background white
	$self configure {*}$args
	#bind $win <Configure> [mymethod rescale %w %h]
	#$self rescale [winfo width $win] [winfo height $hull]
	foreach line {mag-1 sum2-1 mag-2 sum2-2 mag-3 sum2-3 tap} { $win add line $line }
	after $data(timeout) [mymethod poll]
    }
    
    method is-busy {} { return 0 }
    method activate {} { return 0 }
    method deactivate {} { return 0 }
    method exposed-options {} { return {-filter1 -filter2 -filter3 -tap} }
    method {info-option -filter1} {} { return {goertzel filter name} }
    method {info-option -filter2} {} { return {goertzel filter name} }
    method {info-option -filter3} {} { return {goertzel filter name} }
    method {info-option -tap} {} { return {midi tap name} }

    method poll {} {
	foreach opt {-filter1 -filter2 -filter3 -tap} {
	    if {$options($opt) ne {}} { 
		if { ! [catch {$options($opt) get} get]} {
		    lappend data(input) $opt $get
		} else {
		    error "sdrtk::goertzel: $options($opt) get threw $get"
		}
	    }
	}
	if {$data(input) ne {}} {
	    after idle [mymethod process] 
	}
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
		{4 -filter?} {
		    # complex goertzel output
		    foreach {frame mag arg sum2} $get break
		    if {$data(last$opt) == $frame} {
			incr data(too-soon)
			continue
		    }
		    set data(last$opt) $frame
		    set i [string index $opt end]
		    #$self extend mag-$i $frame [expr {20*log10($mag)}]
		    #$self extend sum2-$i $frame [expr {20*log10($sum2)}]
		    # puts "$opt $frame $mag $arg $sum2"
		}
		{3 -filter?} {
		    # real goertzel output
		    foreach {frame mag sum2} $get break
		    if {$data(last$opt) == $frame} {
			incr data(too-soon)
			continue
		    }
		    set data(last$opt) $frame
		    set i [string index $opt end]
		    $self extend mag-$i $frame [expr {20*log10($mag)}]
		    #$self extend sum2-$i $frame [expr {20*log10($sum2)}]
		    # puts "$opt $frame $mag $sum2"
		}
		{1 -tap} {
		    foreach item $get {
			foreach {frame bytes} $item break
			if {[binary scan $bytes ccc cmd note vel] != 3} continue
			$self extend tap $frame [expr {20*(!$vel)}] $frame [expr {20*$vel}]
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
	    -filter1 -
	    -filter2 -
	    -filter3 -
	    -tap {
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
