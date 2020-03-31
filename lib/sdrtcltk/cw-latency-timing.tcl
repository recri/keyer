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
package provide sdrtcltk::cw-latency-timing 1.0.0

#
# Run two detone components and compare the timing
# of the signals arriving at each.
#
# Opened a can of worms.  My Goertzel filters need to be configured
# for a -bandwidth that refers to the sample rate of the output of the
# filter, so I was configuring it wrong.  Watching the filter output
# as I varied the -bandwidth I see regions of click detection, regions
# of oscillatory output, and small regions where the output approximates
# the cw keying envelope.  So, need to understand how the shape of the
# output varies with bandwidth, and how the magnitude of the output varies
# with bandwidth, signal strength, etc..  And then get back to computing
# the delay of a signal.
#
# insert a known delay to see how the timing works
# insert a known attenuation to see how the detection varies
# insert a series of meters to measure the responses
# figure out how to properly parameterize the Goertzel filters
#
package require Tk
package require snit

package require sdrtcl::keyer-detone
package require sdrtcl::midi-tap
package require sdrtcl::gain
package require sdrtcl::meter-tap
package require sdrtcl::sample-delay
package require sdrtcl::jack

namespace eval ::sdrtcltk {}

snit::widget sdrtcltk::cw-latency-timing {
    component detone1
    component detone2
    component miditap1
    component miditap2
    component meter1
    component meter2
    component meter3
    component meter4
    component gain
    component delay
    component text1
    component text2
    component text3

    constructor {args} {
	# puts "cw-latency-timing constructor {$args}"
	set client [winfo name [namespace tail $self]]
	set server [from args -server {}]
	set xargs {}
	if {$server ne {}} { lappend xargs -server $server }
	install detone1 using sdrtcl::keyer-detone $self.detone1 -client ${client}1 {*}$xargs
	install detone2 using sdrtcl::keyer-detone $self.detone2 -client ${client}2 {*}$xargs
	install miditap1 using sdrtcl::midi-tap $self.miditap1 -client ${client}t1 {*}$xargs
	install miditap2 using sdrtcl::midi-tap $self.miditap2 -client ${client}t2 {*}$xargs
	install meter1 using sdrtcl::meter-tap $self.meter1 -client ${client}m1 {*}$xargs
	install meter2 using sdrtcl::meter-tap $self.meter2 -client ${client}m2 {*}$xargs
	install meter3 using sdrtcl::meter-tap $self.meter3 -client ${client}m3 {*}$xargs
	install meter4 using sdrtcl::meter-tap $self.meter4 -client ${client}m4 {*}$xargs
	install gain using sdrtcl::gain $self.gain -client ${client}g
	install delay using sdrtcl::sample-delay $self.delay -client ${client}d {*}$xargs
	install text1 using text $win.text1
	install text2 using text $win.text2
	install text3 using text $win.text3

	$text1 configure -width 30 -height 15 -exportselection true {*}$args
	$text2 configure -width 30 -height 15 -exportselection true {*}$args
	$text3 configure -width 30 -height 15 -exportselection true {*}$args
	grid $text1 -row 0 -column 0 -sticky nsew
	grid $text2 -row 0 -column 1 -sticky nsew
	grid $text3 -row 0 -column 2 -sticky nsew
	grid [ttk::frame $win.row1] -row 1 -column 0 -columnspan 3 -sticky nsew
	foreach i {1 2 3 4} {
	    pack [ttk::labelframe $win.row1.col$i -text Meter$i] -side left -expand true -fill x
	    pack [ttk::label $win.row1.col$i.lbl -textvar [myvar data(meter$i)]]
	}
    }

    option -verbose -default 0 -configuremethod ConfigAll
    option -server -default {} -configuremethod ConfigAll
    option -client -default 0 -configuremethod ConfigAll

    option -chan -default 1 -configuremethod ConfigMidi
    option -note -default 0 -configuremethod ConfigMidi

    option -freq -default 700 -configuremethod ConfigDetone
    option -bandwidth -default 700 -configuremethod ConfigDetone
    option -on -default 4 -configuremethod ConfigDetone
    option -off -default 3 -configuremethod ConfigDetone
    option -timeout -default 100 -configuremethod ConfigDetone;	# not implemented in component
    
    option -delay -default 500 -configuremethod ConfigDelay

    option -gain -default -6 -configuremethod ConfigGain

    option -period -default 4096 -configuremethod ConfigMeter
    option -decay -default 0.999 -configuremethod ConfigMeter
    option -reduce -default mag2 -configuremethod ConfigMeter

    method exposed-options {} { return {-verbose -server -client -chan -note -freq -bandwidth -on -off -timeout -delay -gain -period -decay -reduce} }

    variable optioninfo -array {
    }

    method info-option {opt} {
	if { ! [catch {$detone1 info option $opt} info] ||
	     ! [catch {$miditap1 info option $opt} info] ||
	     ! [catch {$delay info option $opt} info] ||
	     ! [catch {$gain info option $opt} info] ||
	     ! [catch {$meter1 info option $opt} info]} { 
	    return $info
	}
	if {[info exists optioninfo($opt)]} {
	    return $optioninfo($opt)
	}
	return {}
    }

    delegate option * to hull
    delegate method * to hull
    
    method AdjustDelay {d} { if { ! [$delay is-busy] } { $self configure -delay [expr {int($d)}] } }

    method is-busy {} { return 0 }

    method activate {} { 
	$detone1 activate
	$detone2 activate
	$miditap1 activate
	$miditap1 start
	$miditap2 activate
	$miditap2 start
	$meter1 activate
	$meter2 activate
	$meter3 activate
	$meter4 activate
	$gain activate
	$delay activate
	$delay start
	set handler [after 100 [mymethod timeout]]
    }
    method deactivate {} { 
	after cancel $handler
	$detone1 deactivate
	$detone2 deactivate
	$miditap1 stop
	$miditap1 deactivate
	$miditap2 stop
	$miditap2 deactivate
	$meter1 deactivate
	$meter2 deactivate
	$meter3 deactivate
	$meter4 deactivate
	$gain deactivate
	$delay stop
	$delay deactivate
    }
    method ConfigDetone {opt val} {
	set options($opt) $val
	$detone1 configure $opt $val
	$detone2 configure $opt $val
    }
    method ConfigMidi {opt val} {
	set options($opt) $val
	$self ConfigDetone $opt $val
	$miditap1 configure $opt $val
	$miditap2 configure $opt $val
    }
    method ConfigDelay {opt val} {
	set options($opt) $val
	if { ! [$delay is-busy] } { $delay configure -delay [expr {int($val)}] }
    }
    method ConfigGain {opt val} {
	set options($opt) $val
	$gain configure -gain $val
    }
    method ConfigMeter {opt val} {
	set options($opt) $val
	$meter1 configure $opt $val
	$meter2 configure $opt $val
	$meter3 configure $opt $val
	$meter4 configure $opt $val
    }
    proc postevents {miditap text} {
	set events {}
	if {[$miditap state]} {
	    foreach event [$miditap get] {
		foreach {frame midi} $event break
		binary scan $midi ccc cmd note vel
		set chan [format %x [expr {$cmd&0x0F}]]
		set cmd  [format %02x [expr {$cmd&0xF0}]]
		set time [sdrtcl::jack frames-to-time $frame]
		$text insert end [format "%8ld %8ld: $vel\n" $frame $time]
		lappend events $frame $time $vel
		if {$chan ne {0} || $cmd ne {90} || $note ne {0}} {
		    $text insert end "    ?$cmd $chan $note?\n"
		}
		$text see end
	    }
	}
	return $events
    }
    method timeout {} {
	# get new text
	if {[catch {
	    set e1 [postevents $miditap1 $text1]
	    set e2 [postevents $miditap2 $text2]
	    foreach {f1 t1 v1} $e1 {f2 t2 v2} $e2 {
		if {$f1 eq {} || $f2 eq {}} break
		$text3 insert end [format "%8ld %8ld $v1 $v2\n" [expr {$f2-$f1}] [expr {$t2-$t1}]]
		$text3 see end
	    }
	    set data(meter1) [$meter1 get]
	    set data(meter2) [$meter2 get]
	    set data(meter3) [$meter3 get]
	    set data(meter4) [$meter4 get]
	} error]} { puts $error }
	set handler [after 250 [mymethod timeout]]
    }

}
