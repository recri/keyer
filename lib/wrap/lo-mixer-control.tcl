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
## lo-mixer-control - local oscillator mixer control
##
package provide lo-mixer-control 1.0.0

package require Tk
package require sdrtcl::jack
package require sdrtcl::lo-mixer

namespace eval ::lo-mixer-control {}

proc ::lo-mixer-control::set-freq {w} {
    upvar \#0 $w data
    $data(-name) configure -freq $data(-freq)
}

proc ::lo-mixer-control::shutdown {cw w} {
    if {$w ne $cw} return
    upvar \#0 $w data
    rename $data(-name) {}
}

proc ::lo-mixer-control {w args} {
    ttk::frame $w
    upvar \#0 $w data
    set plim [expr {int([sdrtcl::jack sample-rate]/200.0)*100}]
    set nlim [expr {-$plim}]
    array set data [list -freq 10000 -min-freq $nlim -max-freq $plim -name lo-mixer]
    array set data $args
    sdrtcl::lo-mixer $data(-name)
    grid [ttk::label $w.lm -text freq:] -row 0 -column 0
    grid [ttk::spinbox $w.mode -textvar ${w}(-mode) -command [list ::lo-mixer-control::set-freq $w] -textvar ${w}(-freq) \
	      -from $data(-min-freq) -to $data(-max-freq) -increment 100 -width 6 \
	     ] -row 0 -column 1
    ::lo-mixer-control::set-freq $w
    bind . <Destroy> [list ::lo-mixer-control::shutdown $w %W]
    return $w
}
