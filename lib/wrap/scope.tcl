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
package provide scope 1.0.0

package require wrap
package require sdrkit::audio-tap
package require sdrkit::jack

namespace eval ::scope {}
namespace eval ::scope::cmd {}

#
# scope block
#
# a simple two channel scope
#
proc ::scope::update {w} {
    upvar #0 $w data
    # the milliseconds displayed on screen, ms/div * 10div
    set ms_per_screen [expr {$data(hdivision)*10}]
    # the samples per millisecond, samples/sec / 1000ms/sec
    set samples_per_ms [expr {[sdrkit::jack sample-rate]/1000.0}]
    # the number of samples on screen
    set samples_per_screen [expr {$ms_per_screen * $samples_per_ms}]
    # the number of pixels per sample
    if {[catch {
	set pixels_per_sample [expr {$data(wd) / $samples_per_screen}]
    } error]} {
	set pixels_per_sample [expr {[winfo width $w] / $samples_per_screen}]
    }
    # get the current sample buffer
    set b [::scope::cmd::$w]
    # count the samples received
    set ns [expr {[string length $b]/8}]
    # if that isn't enough, then get more next time
    if {$ns < $samples_per_screen * 2} {
	::scope::cmd::$w -b [make_binary [expr {$samples_per_screen * 2}]]
    }
    # compute the number of floats to scan
    set nf [expr {int(min($ns,$samples_per_screen*2))}]
    set n [binary scan $b f$nf vals]
    if { ! $data(freeze)} {
	if {$n == 1 && [llength $vals] == $nf} {
	    set is {}
	    set qs {}
	    set t 0
	    foreach {i q} $vals {
		lappend is $t $i
		lappend qs $t $q
		incr t
	    }
	    if { ! [info exists data(itrace)]} {
		set data(itrace) [$w.c create line $is -fill blue -tags {trace itrace}]
		set data(qtrace) [$w.c create line $qs -fill red -tags {trace qtrace}]
	    } else {
		$w.c coords $data(itrace) $is
		$w.c coords $data(qtrace) $qs
	    }
	    # move y0 to center screen
	    # move trigger sample to left
	    $w.c move trace 0 $data(y0)
	    # scale according sweep rate and sensitivity
	    $w.c scale trace 0 $data(y0) $pixels_per_sample [expr {$data(yg)/$data(vdivision)}]
	    # move
	} else {
	    puts "buffer length is [string length $b]"
	    puts "binary scan tap == $n"
	    puts "llength \$vals == [llength $vals]"
	}
    }
    ::wrap::cleanup_after $w [after 100 [list ::scope::update $w]]
}

proc ::scope::configure {bw w width height} {
    upvar #0 $w data
    if {$bw eq "$w.c"} {
	set x0 [expr {$width/2.0}]
	set y0 [expr {$height/2.0}]
	set wd [expr {$width-3}]
	set ht [expr {$height-3}]
	set xg [expr {$wd/10.0}]
	set yg [expr {$ht/8.0}]
	set xmg [expr {$xg/5.0}]
	set ymg [expr {$yg/5.0}]
	if { ! [info exists data(x0)]} {
	    for {set i 0} {$i <= 10} {incr i} {
		if {$i <= 8} {
		    set y [expr {$i*$yg+1}]
		    set data(h$i) [$w.c create line 0 $y $wd $y]
		}
		set x [expr {$i*$xg+1}]
		set data(v$i) [$w.c create line $x 0 $x $ht]
	    }
	} else {
	    for {set i 0} {$i <= 10} {incr i} {
		if {$i <= 8} {
		    set y [expr {$i*$yg+1}]
		    $w.c coords $data(h$i) 0 $y $wd $y
		}
		set x [expr {$i*$xg+1}]
		$w.c coords $data(v$i) $x 0 $x $ht
	    }
	}
	array set data [list x0 $x0 y0 $y0 wd $wd ht $ht xg $xg yg $yg xmg $xmg ymg $ymg]
    }
}

proc ::scope::scope {w} {
    upvar #0 $w data
    ::wrap::default_window $w
    ::wrap::cleanup_func $w [::sdrkit::audio-tap ::scope::cmd::$w -complex 1]
    
    bind $w <Configure> [list ::scope::configure %W $w %w %h]
    grid [canvas $w.c -width 400 -height 320] -row 0 -column 0 -sticky nsew
    
    grid [ttk::frame $w.f] -row 0 -column 1 -stick n
    set row -1
    # vertical controls
    pack [ttk::frame $w.v -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.v.l -text {Vertical}] -row [incr row] -column 0
    grid [ttk::label $w.v.pl -text {Position up/down}] -row [incr row] -column 0
    grid [ttk::scale $w.v.p -from -100 -to 100 -variable ${w}(voffset)] -row [incr row] -column 0 -sticky ew
    grid [ttk::label $w.v.dl -text {Sense units/div}] -row [incr row] -column 0
    grid [spinbox $w.v.d -textvariable ${w}(vdivision) -values [lreverse {
	1000 500 250
	100 50 25
	10 5 2.5
	1 0.5 0.25
	0.1 0.05 0.025
	0.01 0.005 0.0025
	0.001 0.0005 0.00025
	0.0001 0.00005 0.000025
	0.00001 0.000005 0.0000025
    }]] -row [incr row] -column 0 -sticky ew
    set data(voffset) 0
    set data(vdivision) 1
    
    # horizontal controls
    pack [ttk::frame $w.h -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.h.l -text {Horizontal}] -row [incr row] -column 0
    grid [ttk::label $w.h.pl -text {Position left/right}] -row [incr row] -column 0
    grid [ttk::scale $w.h.p -from -100 -to 100 -variable ${w}(hoffset)] -row [incr row] -column 0 -sticky ew
    grid [ttk::label $w.h.dl -text {Sweep ms/div}] -row [incr row] -column 0
    grid [spinbox $w.h.d -textvariable ${w}(hdivision) -values [lreverse {
	1000 500 250
	100 50 25
	10 5 2.5
	1 0.5 0.25
	0.1 0.05 0.025
	0.01 0.005 0.0025
	0.001 0.0005 0.00025
	0.0001 0.00005 0.000025
    }]] -row [incr row] -column 0
    set data(hoffset) 0
    set data(hdivision) 1
    
    # trigger controls
    pack [ttk::frame $w.t -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.t.l -text {Trigger}] -row [incr row] -column 0
    grid [ttk::menubutton $w.t.t -textvar ${w}(trigger) -menu $w.t.t.m] -row [incr row] -column 0 -sticky ew
    menu $w.t.t.m -tearoff no
    foreach t {ilevel qlevel free} {
	$w.t.t.m add radiobutton -label $t -value $t -variable ${w}(trigger)
    }
    grid [ttk::scale $w.t.tl -from -100 -to 100 -variable ${w}(trigger-level)] -row [incr row] -column 0 -sticky ew
    set data(trigger) ilevel
    set data(trigger-level) 0
    
    pack [ttk::frame $w.d -border 2 -relief raised] -in $w.f -side top -fill x -expand true
    grid [ttk::label $w.d.l -text {Display}] -row [incr row] -column 0 -sticky ew
    grid [ttk::menubutton $w.d.d -textvar ${w}(display) -menu $w.d.d.m] -row [incr row] -column 0 -sticky ew
    menu $w.d.d.m -tearoff no
    foreach d {{i and q} {i only} {q only} {i vs q}} {
	$w.d.d.m add radiobutton -label $d -value $d -variable ${w}(display)
    }
    grid [ttk::checkbutton $w.d.f -text Freeze -variable ${w}(freeze)] -row [incr row] -column 0 -sticky ew
    set data(display) {i and q}
    set data(freeze) 0
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    ::wrap::cleanup_after $w [after 500 [list ::scope::update $w]]
    return $w
}

