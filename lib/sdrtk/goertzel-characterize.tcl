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

package provide sdrtk::goertzel-characterize 1.0.0

package require Tk
package require snit

#
# run a multi-factor test over Goertzel filters.
# vary the signal strength from strong to undetected,
# run the added noise from not perceptible to completely masking the signal,
# run the Goertzel filters from wide to narrow bandwidth
# and from exactly on frequency to everywhere
#
# record the response of the real and complex Goertzel filters.
#
# so each experiment specifies
# signal frequency, signal strength, noise strength, filter, filter frequency, filter bandwidth, 
# and records filter magnitude, band energy, and filter phase
#
# Well, that was fun and confusing.  Now, record the response of a few filters to presence and
# absence of tones, see if there's a decision algorithm that works with mag and sum2 as 

snit::widget sdrtk::goertzel-characterize {
    option -ins -default {}
    option -osc -default {}
    option -noise -default {}
    option -filter1 -default {}
    option -filter2 -default {}
    option -center-f -default 700
    option -offset-f -default {-5000 -2000 -1000 -500 -250 0 250 500 1000 2000 5000}
    option -bandwidth -default {6000 3000 1500 750 375}
    option -osc-gain -default {-20 -30 -40 -50 -60}
    option -noise-gain -default {-60 -50 -40 -30 -20}
    option -timeout -default 6
    option -replications -default 10

    variable data -array {
	results {}
	current-results {}
	all-settings {}
	current-settings {}
	paused 1
	-filter1 {}
	-filter2 {}
    }
    
    proc values {key list} {
	set values [dict create]
	foreach dict $list { dict incr values [dict get $dict $key] }
	return [dict keys $values]
    }
    constructor {args} {
	$self configure {*}$args
	pack [ttk::label $win.l1 -textvar [myvar data(current-settings)] -width 100] -side top
	pack [ttk::label $win.l2 -textvar [myvar data(current-results)] -width 100] -side top
	foreach f $options(-center-f) {
	    foreach df $options(-offset-f) {
		set df [expr {$f+$df}]
		foreach bw $options(-bandwidth) {
		    foreach go $options(-osc-gain) {
			foreach gn $options(-noise-gain) {
			    lappend data(all-settings) [dict create f $f go $go gn $gn df $df bw $bw]
			}
		    }
		}
	    }
	}
	#set n [llength $data(all-settings)]
	#puts "$n experiments generated, expect [expr {6*$n/1000.0}] seconds"
	puts [concat [dict keys [lindex $data(all-settings) 0]] {frame mag1 sum21 mag2 arg2 sum22}]
	after idle [mymethod start-processing]
    }
    
    method is-busy {} { return 0 }
    method activate {} { return 0 }
    method deactivate {} { return 0 }
    method exposed-options {} { return {-filter1 -filter2 -ins -osc -noise -replications} }
    method {info-option -filter1} {} { return {test goertzel filter name} }
    method {info-option -filter2} {} { return {test goertzel filter name} }
    method {info-option -osc} {} { return {test oscillator name} }
    method {info-option -noise} {} { return {test noise generator name} }
    method {info-option -ins} {} { return {test midi insert name} }
    method {info-option -replications} {} { return {number of measurements averaged} }

    method {tone on} {} {
	set data(paused) 0
	$options(-ins) puts [binary format ccc 0x90 0 1]
    }

    method {tone off} {} {
	$options(-ins) puts [binary format ccc 0x90 0 0]
	set data(paused) 1
    }
    
    method next-setting {} {
	if {[llength $data(all-settings)] > 0} {
	    set data(current-settings) [lindex $data(all-settings) 0]
	    set data(all-settings) [lrange $data(all-settings) 1 end]
	    dict with data(current-settings) {
		::options configure -$options(-osc)-freq $f -$options(-osc)-gain $go -$options(-noise)-level $gn \
		    -$options(-filter1)-freq $df -$options(-filter2)-freq $df \
		    -$options(-filter1)-bandwidth $bw -$options(-filter2)-bandwidth $bw
	    }
	    return 1
	}
	return 0
    }
    
    method start-processing {} {
	# this has to wait until ::options is defined
	$self next-setting
	#set data(paused) 0
	$self tone on
	after $options(-timeout) [mymethod poll]
    }
    
    method poll {} {
	if { ! $data(paused)} {
	    set input {}
	    foreach opt {-filter1 -filter2} {
		if {$options($opt) ne {}} { 
		    if {[$options($opt) is-busy]} continue
		    if { ! [catch {$options($opt) get} get]} {
			lappend input $opt $get
		    } else {
			error "sdrtk::goertzel-characterize: $options($opt) get threw $get"
		    }
		}
	    }
	    if {$input ne {}} { 
		after idle [mymethod process $input]
	    }
	}
	after $options(-timeout) [mymethod poll]
    }

    method process {input} {
	# puts "sdrtk::goertzel process called with [llength $input] items queued"
	foreach {opt get} $input {
	    set tag [list [llength $get] $opt]
	    switch -glob $tag {
		{0 -*} continue
		{4 -filter?} -
		{3 -filter?} {
		    # puts "sdrtk::goertzel process lappend data($opt) $get"
		    lappend data($opt) $get
		}
		default {
		    puts "sdrtk::goertzel process switch $tag not caught"
		}
	    }
	}
	if {[llength $data(-filter1)] < $options(-replications) || [llength $data(-filter2)] < $options(-replications)} {
	    # set data(paused) 0
	    $self tone on
	    return
	}
	after idle [mymethod accumulate $data(current-settings) -filter1 $data(-filter1) -filter2 $data(-filter2)]
	set data(-filter1) {}
	set data(-filter2) {}
	$self tone off
	if {[$self next-setting]} {
	    # set data(paused) 0
	    $self tone on
	} else {
	    # we're finished
	    flush stdout
	    after 1000 [destroy .]
	}
    }
    
    method accumulate {settings args} {
	# puts "sdrtk::goertzel accumulate called with [llength $args] args to process"
	# puts $settings
	set sum [dict create]
	foreach {opt val} $args {
	    foreach item $val {
		set frame [lindex $item 0]
		set index [llength $item]
		dict set sum $frame $index $item
	    }
	}
	#puts [concat [dict keys $settings] {frame mag1 sum21 mag2 arg2 sum22}]
	foreach frame [dict keys $sum] {
	    set values [dict values $settings]
	    lappend values $frame
	    if {[dict exists $sum $frame 3]} {
		foreach {frame mag sum2} [dict get $sum $frame 3] break
		lappend values $mag $sum2
	    } else {
		lappend values NA NA
	    }
	    if {[dict exists $sum $frame 4]} {
		foreach {frame mag arg sum2} [dict get $sum $frame 4] break
		lappend values $mag $arg $sum2
	    } else {
		lappend values NA NA NA
	    }
	    puts $values
	}

		
	    
	set data(current-results) $settings
	#lappend data(results) $settings
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
