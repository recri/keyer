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

##
## panorama-control - combined panorama and controller
##
package provide panorama-control 1.0.0

package require panorama

proc ::panorama-control {w args} {
    upvar \#0 $w data
    ttk::frame $w
    array set data {polyphase {no polyphase} pal {palette 0} min {min -160} max {max 0}}
    array set data $args
    pack [panorama $w.p {*}$args] -side top -fill both -expand true
    pack [ttk::frame $w.m] -side top
    # polyphase spectrum control
    pack [ttk::menubutton $w.m.s -textvar ${w}(polyphase) -menu $w.m.s.m] -side left
    menu $w.m.s.m -tearoff no
    foreach x {1 2 4 8 16 32} {
	if {$x == 1} {
	    set label {no polyphase}
	} else {
	    set label "polyphase $x"
	}
	$w.m.s.m add radiobutton -label $label -variable ${w}(polyphase) -value $label -command [list ::panorama::configure $w.p -polyphase $x]
    }
    # waterfall palette control
    pack [ttk::menubutton $w.m.p -textvar ${w}(pal) -menu $w.m.p.m] -side left
    menu $w.m.p.m -tearoff no
    foreach p {0 1 2 3 4 5} {
	$w.m.p.m add radiobutton -label "palette $p" -variable ${w}(pal) -value "palette $p" -command [list ::panorama::configure $w.p -pal $p]
    }
    # waterfall/spectrum min dB
    pack [ttk::menubutton $w.m.min -textvar ${w}(min) -menu $w.m.min.m] -side left
    menu $w.m.min.m -tearoff no
    foreach min {-160 -150 -140 -130 -120 -110 -100 -90 -80} {
	$w.m.min.m add radiobutton -label "min $min" -variable ${w}(min) -value "min $min" -command [list ::panorama::configure $w.p -min $min]
    }
    # waterfall/spectrum max dB
    pack [ttk::menubutton $w.m.max -textvar ${w}(max) -menu $w.m.max.m] -side left
    menu $w.m.max.m -tearoff no
    foreach max {0 -10 -20 -30 -40 -50 -60 -70 -80} {
	$w.m.max.m add radiobutton -label "max $max" -variable ${w}(max) -value "max $max" -command [list ::panorama::configure $w.p -max $max]
    }
    return $w
}
