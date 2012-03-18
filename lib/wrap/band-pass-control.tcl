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
## band-pass-control - band pass filter controller
##
package provide band-pass-control 1.0.0

package require Tk
package require sdrkit::filter-complex-bandpass
package require sdrkit::filter-overlap-save

namespace eval ::band-pass-control {}

proc ::band-pass-control::draw-filter {w width center length} {
    if { ! [winfo exists $w]} return
    set wd [winfo width $w]
    set ht [winfo height $w]
    set f0 [expr {0.5+(($center/32000.0)*0.5)}]
    set lo [expr {$f0-(($width/(2*32000.0))*0.5)}]
    set hi [expr {$f0+(($width/(2*32000.0))*0.5)}]
    catch {$w delete all}
    $w create line 0.5 0.0 0.5 1.0 -fill grey
    $w create line $lo 1.0 $lo 0.2 $hi 0.2 $hi 1.0 -fill black
    $w scale all 0 0 $wd $ht
}

proc ::band-pass-control::set-filter {w} {
    upvar \#0 $w data
    # draw-filter .c $data(-width) $data(-center) $data(-filter-length)
    $data(-name) configure -low [expr {$data(-center)-$data(-width)/2}] -high [expr {$data(-center)+$data(-width)/2}] -length  $data(-filter-length)
}

proc ::band-pass-control::set-width {w} { set-filter $w }
proc ::band-pass-control::set-center {w} { set-filter $w }
proc ::band-pass-control::set-filter-length {w} { set-filter $w }

proc ::band-pass-control::shutdown {w} {
    if {$w ne $cw} return
    upvar \#0 $w data
    rename $data(-name) {}
}

proc ::band-pass-control {w args} {
    ttk::frame $w
    upvar \#0 $w data
    array set data {
	-filter sdrkit::filter-complex-bandpass
	-server default
	-name bandpass
	-filter-length 15
	-min-filter-length 3
	-max-filter-length 127
	-center 0
	-min-center -5000
	-max-center  5000
	-width 10000.0
	-min-width 50
	-max-width 10000
    }
    array set data $args
    $data(-filter) $data(-name) 
    ::band-pass-control::set-filter $w

    set row 0
    grid [ttk::label $w.lw -text {filter width}] -row $row -column 0
    grid [ttk::spinbox $w.width -command [list ::band-pass-control::set-width $w] -textvariable ${w}(-width) \
	      -from $data(-min-width) -to $data(-max-width) -increment 50 -width 5 -format %5.0f \
	     ] -row $row -column 1 -sticky ew
    incr row
    grid [ttk::label $w.lc -text {filter center}] -row $row -column 0
    grid [ttk::spinbox $w.center -command [list ::band-pass-control::set-center $w] -textvariable ${w}(-center) \
	      -from $data(-min-center) -to $data(-max-center) -increment 50 -width 5 -format %5.0f \
	     ] -row $row -column 1 -sticky ew
    incr row
    grid [ttk::label $w.ll -text {filter length}] -row $row -column 0
    grid [ttk::spinbox $w.length -command [list ::band-pass-control::set-filter-length $w] -textvariable ${w}(-filter-length) \
	      -from $data(-min-filter-length) -to $data(-max-filter-length) -increment 2 -width 5 -format %3.0f \
	     ] -row $row -column 1 -sticky ew
    incr row

    bind $w <Destroy> [list ::band-pass-control::shutdown  $w %W]

    return $w
}

