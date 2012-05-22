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

package provide sdrui::old-spectrum 1.0.0

package require Tk
package require snit
package require sdrui::tk-spectrum
package require sdrtcl::spectrum-tap
package require sdrtcl::jack

snit::widget sdrui::old-spectrum {
    component capture
    component display

    option -rate -default 48000 -configuremethod Opt-handler

    option -polyphase -default 1
    option -size -default 128 -configuremethod Opt-handler
    option -result -default dB -configuremethod Opt-handler

    option -pal -default 0 -configuremethod Opt-handler

    option -min -default -150 -configuremethod Opt-handler
    option -max -default -0 -configuremethod Opt-handler
    option -zoom -default 1 -configuremethod Opt-handler
    option -pan -default 0 -configuremethod Opt-handler
    option -smooth -default false -configuremethod Opt-handler
    option -center -default 0 -configuremethod Opt-handler
    option -multi -default 1 -configuremethod Opt-handler

    option -server -default default -readonly true
    option -container -readonly yes
    option -control -readonly yes
    option -input -default {} -configuremethod Opt-handler

    variable data -array {
	frequencies {}
	capture-options {-polyphase -size -result}
	display-options {-min -max -smooth -multi -center -rate -zoom -pan}
    }

    method {filter-options} {target} {
	set new {}
	foreach {name val} [array get options] {
	    if {$name in $data($target-options)} {
		lappend new $name $val
	    }
	}
	return $new
    }
    
    method Opt-delegate {opt val} {
	if {$display ne {} && $opt in $data(display-options)} { $display configure $opt $val }
	if {$capture ne {} && $opt in $data(capture-options)} {
	    while {[$capture is-busy]} { after 1 }
	    $capture configure $opt $val
	}
    }

    method {Opt-handler -rate} {value} { set options(-rate) $value; $self Opt-delegate -rate $value }

    method {Opt-handler -size} {value} { set options(-size) $value; $self Opt-delegate -size $value; set data(frequencies) {} }

    method {Opt-handler -result} {value} { set options(-result) $value; $self Opt-delegate -result $value }

    method {Opt-handler -pal} {value} { set options(-pal) $value; $self Opt-delegate -pal $value }

    method {Opt-handler -min} {value} { set options(-min) $value; $self Opt-delegate -min $value }
    method {Opt-handler -max} {value} { set options(-max) $value; $self Opt-delegate -max $value }
    method {Opt-handler -zoom} {value} { set options(-zoom) $value; $self Opt-delegate -zoom $value }
    method {Opt-handler -pan} {value} { set options(-pan) $value; $self Opt-delegate -pan $value }
    method {Opt-handler -smooth} {value} { set options(-smooth) $value; $self Opt-delegate -smooth $value }
    method {Opt-handler -center} {value} { set options(-center) $value; $self Opt-delegate -center $value }
    method {Opt-handler -multi} {value} { set options(-multi) $value; $self Opt-delegate -multi $value }

    method {Opt-handler -input} {input} {
	set options(-input) $input
	if {$input ne {}} {
	    set ports [$options(-control) ccget $input -inport]
	    set input [lindex [split [lindex $ports 0] :] 0]
	}
	$self Opt-delegate -connect $input
    }

    method update {} {
	if { ! [$capture is-busy]} {
	    lassign [$capture get] frame dB
	    binary scan $dB f* dB
	    set n [llength $dB]
	    if {[llength $data(frequencies)] != $n} {
		set data(frequencies) {}
		set maxf [expr {$options(-rate)/2.0}]
		set minf [expr {-$maxf}]
		set df [expr {double($options(-rate))/$options(-size)}]
		for {set f $minf} {$f < $maxf} {set f [expr {$f+$df}]} {
		    lappend data(frequencies) $f
		}
	    }
	    foreach x $data(frequencies) y [concat [lrange $dB [expr {$n/2}] end] [lrange $dB 0 [expr {$n/2-1}]]] {
		lappend xy $x $y
	    }
	    #puts "$xy"
	    $display update $xy
	}
	set data(after) [after 100 [mymethod update]]
    }
    
    constructor {args} {
	set options(-rate) [from args -rate [sdrtcl::jack -server $options(-server) sample-rate]] 
	$self configure {*}$args
	install capture using sdrtcl::spectrum-tap ::spectrum {*}[$self filter-options capture]
	install display using sdrui::tk-spectrum $win.s {*}[$self filter-options display]
	pack $win.s -side top -fill both -expand true
	pack [ttk::frame $win.m] -side top
	
	# spectrum selection
	#puts "making input selector: -input {$options(-input)}"
	pack [ttk::menubutton $win.m.i -textvar [myvar data(input)] -menu $win.m.i.m] -side left
	menu $win.m.i.m -tearoff no
	$win.m.i.m add radiobutton -label none -variable [myvar data(input)] -value none -command [mymethod configure -input {}]
	if {$options(-input) eq {}} { set data(input) none }
	foreach i [{*}$options(-control) part-list] {
	    if {[regexp {^dsp-(rx|tx|rxtx)-.*spectrum-(.*)$} $i input prefix suffix]} {
		set label $prefix-$suffix
		$win.m.i.m add radiobutton -label $label -variable [myvar data(input)] -value $label -command [mymethod configure -input $input]
		if {$options(-input) eq $input} { set data(input) $label }
	    }
	}

	# spectrum fft size control
	pack [ttk::menubutton $win.m.size -textvar [myvar data(size)] -menu $win.m.size.m] -side left
	menu $win.m.size.m -tearoff no
	foreach x {64 128 256 512 1024 2048 4096 8192} {
	    set label "size $x"
	    if {$options(-size) == $x} { set data(size) $label }
	    $win.m.size.m add radiobutton -label $label -variable [myvar data(size)] -value $label -command [mymethod configure -size $x]
	}
	
	# polyphase spectrum control
	pack [ttk::menubutton $win.m.s -textvar [myvar data(polyphase)] -menu $win.m.s.m] -side left
	menu $win.m.s.m -tearoff no
	foreach x {1 2 4 8 16 32} {
	    if {$x == 1} {
		set label {no polyphase}
	    } else {
		set label "polyphase $x"
	    }
	    if {$options(-polyphase) == $x} { set data(polyphase) $label }
	    $win.m.s.m add radiobutton -label $label -variable [myvar data(polyphase)] -value $label -command [mymethod configure -polyphase $x]
	}
	
	# multi-trace spectrum control
	pack [ttk::menubutton $win.m.multi -textvar [myvar data(multi)] -menu $win.m.multi.m] -side left
	menu $win.m.multi.m -tearoff no
	foreach p {1 2 4 6 8 10 12} {
	    set label "multi $p"
	    if {$options(-multi) == $p} { set data(multi) $label }
	    $win.m.multi.m add radiobutton -label $label -variable [myvar data(multi)] -value $label -command [mymethod configure -multi $p]
	}

	if {0} {
	    # waterfall palette control
	    pack [ttk::menubutton $win.m.p -textvar [myvar data(pal)] -menu $win.m.p.m] -side left
	    menu $win.m.p.m -tearoff no
	    foreach p {0 1 2 3 4 5} {
		set label "palette $p"
		if {$options(-pal) == $p} { set data(pal) $label }
		$win.m.p.m add radiobutton -label $label -variable [myvar data(pal)] -value $label -command [mymethod configure -pal $p]
	    }
	}

	# waterfall/spectrum min dB
	pack [ttk::menubutton $win.m.min -textvar [myvar data(min)] -menu $win.m.min.m] -side left
	menu $win.m.min.m -tearoff no
	foreach min {-160 -150 -140 -130 -120 -110 -100 -90 -80} {
	    set label "min $min dB"
	    if {$options(-min) == $min} { set data(min) $label }
	    $win.m.min.m add radiobutton -label $label -variable [myvar data(min)] -value $label -command [mymethod configure -min $min]
	}
	
	# waterfall/spectrum max dB
	pack [ttk::menubutton $win.m.max -textvar [myvar data(max)] -menu $win.m.max.m] -side left
	menu $win.m.max.m -tearoff no
	foreach max {0 -10 -20 -30 -40 -50 -60 -70 -80} {
	    set label "max $max dB"
	    if {$options(-max) == $max} { set data(max) $label }
	    $win.m.max.m add radiobutton -label $label -variable [myvar data(max)] -value $label -command [mymethod configure -max $max]
	}
	
	# zoom in/out
	pack [ttk::menubutton $win.m.zoom -textvar [myvar data(zoom)] -menu $win.m.zoom.m] -side left
	menu $win.m.zoom.m -tearoff no
	foreach zoom {1 2.5 5 10 25 50 100} {
	    set label "zoom $zoom x"
	    if {$options(-zoom) == $zoom} { set data(zoom) $label }
	    $win.m.zoom.m add radiobutton -label $label -variable [myvar data(zoom)] -value $label -command [mymethod configure -zoom $zoom]
	}
	
	# scroll/pan
	
	# start capturing
	set data(after) [after 100 [mymethod update]]
    }

    destructor {
	catch {after cancel $data(after)}
    }
}

