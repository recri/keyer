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
package provide waterfall 1.0.0

package require Tk

##
## waterfall
##

namespace eval ::waterfall {
    array set default_data {
	-height 200
	-atten 0
	-pal 0
	-min -125.0
	-max -60.0
	-scale 1.0
	-offset 0.0
    }
}

proc ::waterfall::hotiron {hue pal} {
    switch $pal {
	0 { lassign [list [expr {3*($hue+0.03)}] [expr {3*($hue-.333333)}] [expr {3*($hue-.666667)}]] r g b }
	1 { lassign [list [expr {3*($hue+0.03)}] [expr {3*($hue-.666667)}] [expr {3*($hue-.333333)}]] r g b }
	2 { lassign [list [expr {3*($hue-.666667)}] [expr {3*($hue+0.03)}] [expr {3*($hue-.333333)}]] r g b }
	3 { lassign [list [expr {3*($hue-.333333)}] [expr {3*($hue+0.03)}] [expr {3*($hue-.666667)}]] r g b }
	4 { lassign [list [expr {3*($hue-.333333)}] [expr {3*($hue-.666667)}] [expr {3*($hue+0.03)}]] r g b }
	5 { lassign [list [expr {3*($hue-.666667)}] [expr {3*($hue-.333333)}] [expr {3*($hue+0.03)}]] r g b }
    }
    return \#[format {%02x%02x%02x} [expr {int(255*min(1,max($r,0)))}] [expr {int(255*min(1,max($g,0)))}] [expr {int(255*min(1,max($b,0)))}]]
}

proc ::waterfall::pixel {w level} {
    upvar #0 ::waterfall::$w data
    # clamp to percentage of range
    set level [expr {min(1,max(0,($level-$data(-min))/($data(-max)-$data(-min))))}]
    # use 100 levels
    set i color-$data(-pal)-[expr {int(100*$level)}]
    if { ! [info exists data($i)]} {
	set data($i) [hotiron $level $data(-pal)]
	# puts "assigned $data($i) to level $level"
    }
    return $data($i)
}

proc ::waterfall::destroy {w} {
    upvar #0 ::waterfall::$w data
    foreach img [array names data img-*] {
	rename $data($img) {}
    }
}

proc ::waterfall::update {w xy} {
    upvar #0 ::waterfall::$w data

    set scanline {}
    set x0 [lindex $xy 0]
    foreach {x y} $xy {
	lappend scanline [pixel $w [expr {$y+$data(-atten)}]]
    }
	
    # scroll all the canvas images down by 1
    $w move all 0 1

    # create a new canvas image
    set i $data(line-number)
    set data(img-$i) [image create photo]
    $data(img-$i) put [list $scanline]
    set data(item-$i) [$w create image $x0 0 -anchor nw -image $data(img-$i)]
    $w scale $data(item-$i) 0 0 $data(-scale) 1
    $w move $data(item-$i) $data(-offset) 0

    # increment our scanline index
    incr data(line-number)
}

proc ::waterfall::configure {w args} {
    upvar #0 ::waterfall::$w data
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
	# puts "waterfall::configure -scale $data(-scale) -offset $data(-offset) bbox [$w bbox all]"
    }
}
    
proc ::waterfall::defaults {} {
    return [array get ::waterfall::default_data]
}

proc ::waterfall::waterfall {w args} {
    upvar #0 ::waterfall::$w data
    array set data [::waterfall::defaults]
    array set data $args
    canvas $w -height $data(-height) -bg black
    set data(line-number) 0
    return $w
}

proc ::waterfall {w args} {
    return [::waterfall::waterfall $w {*}$args]
}

