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

#package require Tk

#
# how do I make the filter based oscillator do negative frequencies?
# how stable is this oscillator, anyway?  It looks better than the
# one that calls sin and cos.
#

set twopi [expr {2*atan2(0,-1)}]

namespace eval ::tcl {}
namespace eval ::tcl::mathfunc {}
proc ::tcl::mathfunc::square {x} { return [expr {$x*$x}] }

proc oscf-init {hertz srate} {
    set rps [expr {$::twopi * $hertz / $srate}]
    set c [expr {sqrt(1.0 / (1.0 + square(tan($rps))))}]
    set xi [expr {sqrt((1 - $c) / (1 + $c))}]
    ## nope, not this if {$hertz < 0} { set c [expr {-$c}] }
    set x $xi
    set y 0
    set ys [expr {$hertz<0?-1:1}]
    return [list $xi $c $x $y $ys]
}

proc oscf {xi c ox oy ys} {
    set t [expr {($ox + $oy) * $c}]
    ## nope, not this if {$hz < 0} { lassign [list [expr {$t + $oy}] [expr {$t - $ox}]] nx ny
    ## } else { lassign [list [expr {$t - $oy}] [expr {$t + $ox}]] nx ny }
    lassign [list [expr {$t - $oy}] [expr {$t + $ox}]] nx ny
    ## eureka,
    ## the oscillator of the negative frequency
    ## is the complex conjugate
    ## of the oscillator of the positive frequency
    return [list [expr {$ox/$xi}] [expr {$ys*$oy}] [list $xi $c $nx $ny $ys]]
}

proc osct-init {hertz srate} {
    set rps [expr {$::twopi * $hertz / $srate}]
    return [list 0 $rps]
}

proc osct {radians dradians} {
    set x [expr {cos($radians)}]
    set y [expr {sin($radians)}]
    set radians [expr {$radians+$dradians}]
    if {$radians > $::twopi} {
	set radians [expr {$radians-$::twopi}]
    } elseif {$radians < -$::twopi} {
	set radians [expr {$radians+$::twopi}]
    }
    return [list $x $y [list $radians $dradians]]
}

proc quick-test {hertz srate n} {
    set oscf [oscf-init $hertz $srate]
    set osct [osct-init $hertz $srate]
    for {set i 0} {$i < $n} {incr i} {
	lassign [oscf {*}$oscf] xf yf oscf
	lappend xyf $xf $yf
	lassign [osct {*}$osct] xt yt osct
	lappend xyt $xt $yt
    }
    return [list $xyf $xyt]
}

proc compare {hertz srate n} {
    foreach {xyf xyt} [quick-test $hertz $srate $n] {
	set sumxe 0
	set sumxe2 0
	set sumye 0
	set sumye2 0
	foreach {xf yf} $xyf {xt yt} $xyt {
	    set xe [expr {$xf-$xt}]
	    set ye [expr {$yf-$yt}]
	    set sumxe [expr {$sumxe+$xe}]
	    set sumye [expr {$sumye+$ye}]
	    set sumxe2 [expr {$sumxe2+$xe*$xe}]
	    set sumye2 [expr {$sumye2+$ye*$ye}]
	}
	set muxe [expr {$sumxe/$n}]
	set muye [expr {$sumye/$n}]
	set sigxe [expr {sqrt($sumxe2/$n - $muxe*$muxe)}]
	set sigye [expr {sqrt($sumye2/$n - $muye*$muye)}]
	puts "xe $muxe +/- $sigxe, ye $muye +/- $sigye"
    }
}

##
## the question is how good an oscillator it is.
## 1) It should return a unit vector.
## 2) adjacent vectors in sequence should be 2pi*hertz/srate apart
## matching another oscillator isn't that
##
