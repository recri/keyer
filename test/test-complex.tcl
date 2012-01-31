#!/usr/bin/tclsh
# -*- mode: Tcl; tab-width: 8; -*-
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

#
# can the shrinkage in the complex oscillator be avoided by normalizing
#

proc cmag {real imag} {
    return [expr {sqrt($real*$real+$imag*$imag)}]
}

proc cmul {real1 imag1 real2 imag2} {
    return [list [expr {$real1*$real2-$imag1*$imag2}] [expr {$real1*$imag2+$real2*$imag1}]]
}

proc oscz {phase dphase n} {
    while {[incr n -1] >= 0} {
	set phase [cmul {*}$phase {*}$dphase]
    }
    return $phase
}

proc osct {radians dradians n} {
    set two_pi [expr {2*atan2(0,-1)}]
    while {[incr n -1] >= 0} {
	set radians [expr {$radians+$dradians}]
	if {$radians > $two_pi} {
	    set radians [expr {$radians-$two_pi}]
	} elseif {$radians < -$two_pi} {
	    set radians [expr {$radians+$two_pi}]
	}
    }
    return [list [expr {cos($radians)}] [expr {sin($radians)}]]
}

proc test {n} {
    set pi [expr {atan2(0,-1)}]
    set half_pi [expr {$pi/2}]
    set dradians [expr {rand()*$half_pi}]
    set dphase1 [list [expr {cos($dradians)}] [expr {sin($dradians)}]]
    set mag [cmag {*}$dphase1]
    puts "[expr {1-$mag}]"
    set dphase2 [cmul [expr {1.0/$mag}] 0 {*}$dphase1]
    set phase1 [oscz {1 0} $dphase1 $n]
    set phase2 [oscz {1 0} $dphase2 $n]
    set phase3 [osct 0 $dradians $n]
    return [list $dphase1 $dphase2 $phase1 $phase2 $phase3]
}

foreach phase [test 1000000] {
    puts "[expr {1-[cmag {*}$phase]}]"
}
