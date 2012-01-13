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
## frequency display panel
##

package provide frequency 1.0.0

package require Tk

namespace eval ::frequency {
    array set default_data {
	-offset 0.0
	-scale 1.0
	-height 50
	-lo1-offset 0.0
	-lo2-offset {}
    }
}

proc ::frequency::configure {w args} {
    upvar #0 ::frequency::$w data
    array set save [array get data]
    foreach {option value} $args {
	switch -- $option {
	    -scale -
	    -offset {
		set adjustpos 1
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
    if {[info exists adjustpos]} {
	$w move all [expr {-$save(-offset)}] 0
	$w scale all 0 0 [expr {$data(-scale)/$save(-scale)}] 1
	$w move all $data(-offset) 0
    }
}
    
proc ::frequency::update {w xy} {
    upvar #0 ::frequency::$w data
    set x0 [lindex $xy 0]
    set xn [lindex $xy end-1]
    if { ! [info exists data(saved-x0)] || $data(saved-x0) != $x0 || $data(saved-xn) != $xn} {
	set data(saved-x0) $x0
	set data(saved-xn) $xn
	catch {$w delete all}
	set i0 [expr {5000*int(($x0+$data(-lo1-offset))/5000)}]
	set in [expr {5000*int(($xn+$data(-lo1-offset))/5000)}]
	set xy {}
	for {set i $i0} {$i <= $in} {incr i 1000} {
	    if {($i % 10000) == 0} {
		lassign {10 -10} tp tn
		if {($i % 20000) == 0} {
		    set label "[expr {$i/1000}]kHz"
		}
	    } else {
		lassign {5 -5} tp tn
	    }
	    set x [expr {$i-$data(-lo1-offset)}]
	    lappend xy $x 0 $x $tn $x $tp $x 0
	    if {[info exists label]} {
		$w create text $x 12 -text $label -anchor n -tag labels -fill white
		unset label
	    }
	}
	#puts "ticks $xy"
	$w create line $xy -fill white -tags ticks
	#puts "bbox raw [$w bbox all]"
	$w scale all 0 0 $data(-scale) 1
	#puts "bbox scaled [$w bbox all]"
	$w move all $data(-offset) [expr {[winfo height $w]/2.0}]
	#puts "bbox moved [$w bbox all]"
    }
}
proc ::frequency::frequency {w args} {
    upvar #0 ::frequency::$w data
    array set data [array get ::frequency::default_data]
    array set data $args
    canvas $w -height $data(-height) -bg black
    $w create line 0 0 0 0 -fill white -tag ticks
    return $w
}

proc ::frequency::defaults {} {
    return [array get ::frequency::default_data]
}

proc ::frequency {w args} {
    return [::frequency::frequency $w {*}$args]
}

