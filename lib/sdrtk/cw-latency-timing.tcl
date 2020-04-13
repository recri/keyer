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
package provide sdrtk::cw-latency-timing 1.0.0

#
# Run a keyed tone through a delay line and recover the delay time
# from comparison of the original and delayed signals.
#
# This is to measure the roundtrip delay that transmitted signals take
# in going to the hermes lite, being transmitted, leaking into the receiver,
# and being sent back to the host computer.
#
# Originally I thought of using two detone components and compare the 
# timing of the signals arriving at each.  But the resolution is poor,
# so we're looking at the correlation between the original and delayed
# signals from 0 to 20ms or so.
#
# insert a known delay to see how the timing works
# insert a known attenuation to see how the detection varies
#
package require Tk
package require snit

package require sdrtcl::jack
package require dsptcl::vector-dot

namespace eval ::sdrtk {}

snit::widget sdrtk::cw-latency-timing {
    option -mtap1 -default {}
    option -mtap2 -default {}
    option -atap1 -default {}
    option -atap2 -default {}
    component text1
    component text2
    component text3

    variable data -array {
    }

    constructor {args} {
	# puts "cw-latency-timing constructor {$args}"
	install text1 using text $win.text1
	install text2 using text $win.text2
	install text3 using text $win.text3

	$text1 configure -width 30 -height 15 -exportselection true {*}$args
	$text2 configure -width 30 -height 15 -exportselection true {*}$args
	$text3 configure -width 30 -height 15 -exportselection true {*}$args

	grid $text1 -row 0 -column 0 -sticky nsew
	grid $text2 -row 0 -column 1 -sticky nsew
	grid $text3 -row 0 -column 2 -sticky nsew

	set handler [after 500 [mymethod first-timeout]]
    }

    method exposed-options {} { return {-mtap1 -mtap2 -atap1 -atap2} }

    method info-option {opt} {
	switch -- $opt {
	    -mtap1 { return {first midi tap} }
	    -mtap2 { return {second midi tap} }
	    -atap1 { return {first audio tap} }
	    -atap2 { return {second audio tap} }
	    default { return {} }
	}
    }

    delegate option * to hull
    delegate method * to hull
    
    method getevents {mtap} {
	foreach event [$options($mtap) get] {
	    foreach {frame midi} $event break
	    binary scan $midi ccc cmd note vel
	    set chan [format %x [expr {$cmd&0x0F}]]
	    set cmd  [format %02x [expr {$cmd&0xF0}]]
	    dict set data($mtap) $frame "$cmd $chan $note $vel"
	}
    }

    method getbuffs {atap} {
	set buffs [$options($atap) get]
	foreach {frame samples} $buffs break
	if {$frame != 0} { dict set data($atap) $frame $samples }
    }

    method first-timeout {} {
	foreach m {-mtap1 -mtap2} {
	    $options($m) start
	    set data($m) [dict create]
	}
	foreach a {-atap1 -atap2} {
	    foreach {opt val} { -complex 0 -log2size 13 -log2n 6 } {
		::options configure -$options($a)$opt $val
	    }
	    $options($a) start
	    set data($a) [dict create]
	}
	$self timeout
    }

    method timeout {} {
	# get new text
	if {[catch {
	    $self getevents -mtap1
	    $self getevents -mtap2
	    $self getbuffs -atap1
	    $self getbuffs -atap2
	    after idle [mymethod process]
	} error]} { puts $error }
	set handler [after 50 [mymethod timeout]]
    }
    
    # given sample buffers b1 and b2 starting at frames t1 and t2,
    # containing float complex samples, from offsets from o0 to o1,
    # search for the maximum of the offset dot product,
    # dot(b1[t1], b2[t2+o]) as a function of o.
    proc max-offset-dot {b1 b2} {
	if {[string length $b1] != [string length $b2]} {
	    error "buffers not same length" 
	}
	# puts "buffer [expr {[string length $b2]/8}] samples"
	set max -1e12
	set imax {}
	if {[dsptcl::vector-rdot $b1 $b1] > 1e-12 && [dsptcl::vector-rdot $b2 $b2] > 1e-12} {
	    for {set o 0} {$o < 1024} {incr o} {
		set d [dsptcl::vector-rdot $b1 $b2 0 $o]
		if {$d > $max} {
		    set max $d
		    set imax $o
		}
	    }
	    # puts $msg
	}
	return $imax
    }
    method process {} {
	# for each -atap1 buffer
	dict for {t b1} $data(-atap1) {
	    # find closest -atap2 buffer
	    if { ! [dict exists $data(-atap2) $t]} continue
	    set b2 [dict get $data(-atap2) $t]
	    set d [max-offset-dot $b1 $b2]
	    if {$d ne {}} { puts "at $t delay $d samples" }
	    dict unset data(-atap2) $t
	    dict unset data(-atap1) $t
	}
	# clear up everything
	foreach t {-atap1 -atap2 -mtap1 -mtap2} {
	    set data($t) [dict create]
	}
	#exit
    }
}

