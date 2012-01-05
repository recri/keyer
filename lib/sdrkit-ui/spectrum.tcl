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
package provide spectrum 1.0.0

package require Tk
package require sdrkit

namespace eval ::spectrum {}

proc spectrum::capture {w n p tap fft} {
    foreach {f b} [$tap $n] break
    set l [$fft $b]
    binary scan $l f* levels
    set x 0
    foreach y $levels {
	lappend xy $x $y
	incr x
    }
    $w.c coords spectrum $xy
    after $p [list spectrum::capture $w $n $tap $fft]
}

proc spectrum {w n p} {
    ttk::frame $w
    ::sdrkit::atap spectrum_tap
    ::sdrkit::spectrum spectrum_fft $n
    pack [canvas $w.c -width 512 -height 128] -side top -fill both -expand true
    $w.c create line 0 0 0 0 -tag spectrum
    spectrum::capture $w $n $p spectrum_tap spectrum_fft]
}