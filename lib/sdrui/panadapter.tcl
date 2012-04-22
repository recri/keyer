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

package provide sdrui::panadapter 1.0.0

package require Tk
package require snit
package require sdrui::tk-panadapter

snit::widget sdrui::panadapter {

    option -polyphase 1
    option -pal 0
    option -min -160
    option -max 0
    option -connect {}
    option -server -default default -readonly true
    option -partof -readonly yes
    option -control -readonly yes
    option -input -default {} -configuremethod opt-handler

    variable data -array {}

    method set-and-delegate-option {opt val} {
	# store option value
	set options($opt) $val
	# delegate to tk-panadapter
	$win.p configure $opt $val
    }

    proc filter-options {losers opts} {
	set new {}
	foreach {name val} $opts {
	    if {$name ni $losers} {
		lappend new $name $val
	    }
	}
	return $new
    }

    method {opt-handler -input} {input} {
	if {$input eq {}} {
	    $win.p configure -connect {}
	} else {
	    set ports [$options(-control) ccget $input -inport]
	    $win.p configure -connect [lindex [split [lindex $ports 0] :] 0]
	}
    }

    constructor {args} {
	$self configure {*}$args
	pack [sdrui::tk-panadapter $win.p {*}[filter-options {-partof -control -input} [array get options]]] -side top -fill both -expand true
	pack [ttk::frame $win.m] -side top

	# spectrum selection
	puts "making input selector: -input {$options(-input)}"
	pack [ttk::menubutton $win.m.i -textvar [myvar data(input)] -menu $win.m.i.m] -side left
	menu $win.m.i.m -tearoff no
	$win.m.i.m add radiobutton -label none -variable [myvar data(input)] -value none -command [mymethod configure -input {}]
	if {$options(-input) eq {}} { set data(input) none }
	foreach i [{*}$options(-control) list] {
	    if {[regexp {^(rx|tx)-.*spectrum-(.*)$} $i input prefix suffix]} {
		set label $prefix-$suffix
		$win.m.i.m add radiobutton -label $label -variable [myvar data(input)] -value $label -command [mymethod configure -input $input]
		if {$options(-input) eq $input} { set data(input) $label }
	    }
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
	    $win.m.s.m add radiobutton -label $label -variable [myvar data(polyphase)] -value $label -command [mymethod set-and-delegate-option -polyphase $x]
	}

	# waterfall palette control
	pack [ttk::menubutton $win.m.p -textvar [myvar data(pal)] -menu $win.m.p.m] -side left
	menu $win.m.p.m -tearoff no
	foreach p {0 1 2 3 4 5} {
	    set label "palette $p"
	    if {$options(-pal) == $p} { set data(pal) $label }
	    $win.m.p.m add radiobutton -label $label -variable [myvar data(pal)] -value $label -command [mymethod set-and-delegate-option -pal $p]
	}

	# waterfall/spectrum min dB
	pack [ttk::menubutton $win.m.min -textvar [myvar data(min)] -menu $win.m.min.m] -side left
	menu $win.m.min.m -tearoff no
	foreach min {-160 -150 -140 -130 -120 -110 -100 -90 -80} {
	    set label "min $min dB"
	    if {$options(-min) == $min} { set data(min) $label }
	    $win.m.min.m add radiobutton -label $label -variable [myvar data(min)] -value $label -command [mymethod set-and-delegate-option -min $min]
	}

	# waterfall/spectrum max dB
	pack [ttk::menubutton $win.m.max -textvar [myvar data(max)] -menu $win.m.max.m] -side left
	menu $win.m.max.m -tearoff no
	foreach max {0 -10 -20 -30 -40 -50 -60 -70 -80} {
	    set label "max $max dB"
	    if {$options(-max) == $max} { set data(max) $label }
	    $win.m.max.m add radiobutton -label $label -variable [myvar data(max)] -value $label -command [mymethod set-and-delegate-option -max $max]
	}

	# zoom in/out

	# scroll/pan

    }
}
