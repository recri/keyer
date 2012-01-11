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
package provide wrap::oscillator 1.0.0
package require wrap
package require sdrkit::oscillator
namespace eval ::wrap {}
#
# oscillator block, specify frequency
#
proc ::wrap::oscillator {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::oscillator ::wrap::cmd::$w]
    set data(freq) 800
    pack [ttk::label $w.freq -textvar ${w}(freq)] -side left
    pack [ttk::scale $w.scale -length 300 -from 0 -to 10000 -variable ${w}(freq) -command [list ::wrap::oscillator_update $w]] -side left
    return $w
}

proc ::wrap::oscillator_update {w scale} {
    upvar #0 $w data
    ::wrap::cmd::$w configure -frequency $data(freq)
}

