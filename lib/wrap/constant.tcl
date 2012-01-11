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
package provide wrap::constant 1.0.0
package require wrap
package require sdrkit::constant
namespace eval ::wrap {}
#
# constant block, specify value
#
proc ::wrap::constant {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::constant ::wrap::cmd::$w]
    set data(real) 1.0
    set data(imag) 0.0
    pack [ttk::entry $w.real] -side left
    pack [ttk::entry $w.imag] -side left
    pack [ttk::label $w.j -text j] -side left
    pack [ttk::button $w.set -text set -command [list ::wrap::cmd::$w configure -real ${w}(real) -imag ${w}(imag)]] -side left
    return $w
}

