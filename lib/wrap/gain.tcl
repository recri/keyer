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
package provide wrap::gain 1.0.0
package require wrap
package require sdrkit::gain
namespace eval ::wrap {}
#
# gain block: specify scale factor
#
proc ::wrap::gain {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::gain ::wrap::cmd::$w]
    set data(db-gain) 0.0
    pack [ttk::label $w.gain -width 5 -textvar ${w}(db-gain)] -side left
    pack [ttk::scale $w.scale -length 300 -from -160.0 -to 0.0 -variable ${w}(raw-db-gain) -command [list ::wrap::gain_update $w]] -side left
    return $w
}

proc ::wrap::gain_update {w scale} {
    upvar #0 $w data
    set data(db-gain) [format %.1f [expr {$scale/10.0}]]
    set data(gain) [expr {pow(10, $data(db-gain)/10.0)}]
    ::wrap::cmd::$w -gain $data(gain)
}

