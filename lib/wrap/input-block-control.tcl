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
## input-block-control - combined iq swap, delay, correct, gain, and controller
##
package provide input-block-control 1.0.0

package require sdrkit::input-block

namespace eval ::input-block-control {}

proc ::input-block-control::set-swap {w} {
    upvar \#0 $w data
    $data(-name) configure -swap $data(-swap)
}

proc ::input-block-control::set-delay {w} {
    upvar \#0 $w data
    $data(-name) configure -delay $data(-delay)
}

proc ::input-block-control::set-correct {w} {
    upvar \#0 $w data
    set mu [expr {pow(2,$data(-log2mu))*$data(-correct)}]
    $data(-name) configure -mu $mu
}

proc ::input-block-control::set-gain {w} {
    upvar \#0 $w data
    $data(-name) configure -gain $data(-gain)
}

proc ::input-block-control {w args} {
    ttk::frame $w
    upvar \#0 $w data
    array set data {-gain 0 -swap 0 -delay 0 -correct 0 -log2mu -6}
    array set data $args
    sdrkit::input-block $data(-name)

    set row 0
    grid [ttk::label $w.ls -text swap:] -row $row -column 0
    grid [ttk::menubutton $w.swap -textvar ${w}(-swap) -menu $w.swap.m] -row $row -column 1
    menu $w.swap.m -tearoff no
    $w.swap.m add radiobutton -label swapped -variable ${w}(-swap) -value 1 -command [list ::input-block-control::set-swap $w]
    $w.swap.m add radiobutton -label {not swapped} -variable ${w}(-swap) -value 0 -command [list ::input-block-control::set-swap $w]

    incr row
    grid [ttk::label $w.ld -text delay:] -row $row -column 0
    grid [ttk::menubutton $w.delay -textvar ${w}(-delay) -menu $w.delay.m] -row $row -column 1
    menu $w.delay.m -tearoff no
    $w.delay.m add radiobutton -label {no delay} -variable ${w}(-delay) -value 0 -command [list ::input-block-control::set-delay $w]
    $w.delay.m add radiobutton -label {delay I} -variable ${w}(-delay) -value 1 -command [list ::input-block-control::set-delay $w]
    $w.delay.m add radiobutton -label {delay Q} -variable ${w}(-delay) -value -1 -command [list ::input-block-control::set-delay $w]

    incr row
    grid [ttk::label $w.lm -text {iq correct}] -row $row -column 0
    grid [ttk::checkbutton $w.correct -text on/off -variable ${w}(-correct) -onvalue 1 -offvalue 0 -command [list ::input-block-control::set-correct $w]] -row $row -column 1

    incr row
    grid [ttk::label $w.lmu -text {log2(mu)}] -row $row -column 0
    grid [ttk::spinbox $w.mu -from -15 -to 15 -increment 1 -format %4.0f -width 4 -textvar ${w}(-log2mu) -command [list ::input-block-control::set-correct $w]] -row $row -column 1

    incr row
    grid [ttk::label $w.lg -text gain:] -row $row -column 0
    grid [ttk::spinbox $w.gain -from -160 -to 60 -increment 1 -format %4.0f -width 4 -textvariable ${w}(-gain) -command [list ::demod-block-control::set-gain $w]] -row $row -column 1

    return $w
}
