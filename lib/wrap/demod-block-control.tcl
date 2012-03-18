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
## demod-block-control - combined demodulation block and controller
##
package provide demod-block-control 1.0.0

package require Tk
package require sdrkit::demod-block

namespace eval ::demod-block-control {}

proc ::demod-block-control::set-mode {w} {
    upvar \#0 $w data
    $data(-name) configure -mode $data(-mode)
}

proc ::demod-block-control::set-gain {w} {
    upvar \#0 $w data
    $data(-name) configure -gain $data(-gain)
}

proc ::demod-block-control {w args} {
    ttk::frame $w
    upvar \#0 $w data
    array set data {-gain 0 -mode cw}
    array set data $args
    sdrkit::demod-block $data(-name)
    grid [ttk::label $w.lm -text mode:] -row 0 -column 0
    grid [ttk::menubutton $w.mode -textvar ${w}(-mode) -menu $w.mode.m] -row 0 -column 1
    menu $w.mode.m -tearoff no
    foreach v {cw ssb am sam fm} {
	$w.mode.m add radiobutton -label $v -variable ${w}(-mode) -value $v -command [list ::demod-block-control::set-mode $w]
    }
    grid [ttk::label $w.lg -text gain:] -row 1 -column 0
    grid [ttk::spinbox $w.gain -from -160 -to 60 -increment 1 -format %4.0f -width 4 -textvariable ${w}(-gain) -command [list ::demod-block-control::set-gain $w]] -row 1 -column 1
    return $w
}
