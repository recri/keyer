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
package require persistent-spectrum

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

proc ::waterfall::update {w xy} {
    upvar #0 ::waterfall::$w data

    # compute the scan line of pixels
    foreach {freq scan} [::persistent-spectrum::scan $w $xy] break
    set x0 [lindex $freq 0]
	
    # scroll all the canvas images down by 1
    $w move all 0 1

    # create a new canvas image
    set i $data(line-number)
    set data(img-$i) [image create photo]
    $data(img-$i) put $scan
    set data(item-$i) [$w create image $x0 0 -anchor nw -image $data(img-$i)]
    $w scale $data(item-$i) 0 0 $data(-scale) 1
    $w move $data(item-$i) $data(-offset) 0

    # increment our scanline index
    incr data(line-number)
}

proc ::waterfall::destroy {w} {
    upvar #0 ::waterfall::$w data
    ::persistent-spectrum::destroy $w
    foreach img [array names data img-*] {
	rename $data($img) {}
    }
    array unset data
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
	    -rows -
	    -atten -
	    -pal -
	    -min -
	    -max -
	    -min-f -
	    -max-f -
	    -reversed {
		::persistent-spectrum::configure $w $option $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
    if {[info exists adjustpos] && [winfo exists $w]} {
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
    ::persistent-spectrum $w
    ::waterfall::configure $w {*}[::waterfall::defaults]
    ::waterfall::configure $w {*}$args
    canvas $w -height $data(-height) -bg black
    set data(line-number) 0
    return $w
}

proc ::waterfall {w args} {
    return [::waterfall::waterfall $w {*}$args]
}

