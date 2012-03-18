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
## spectrum
##

package provide spectrum 1.0.0

package require Tk

namespace eval ::spectrum {
    # smooth?
    # multiple traces?
    array set default_data {
	-height 100
	-offset 0.0
	-scale 1.0
	-max 0
	-min -160
    }
}

proc ::spectrum::scale {w tag} {
    upvar #0 ::spectrum::$w data
    set yscale [expr {-[winfo height $w]/double($data(-max)-$data(-min))}]
    $w scale $tag 0 0 $data(-scale) $yscale
    $w move $tag $data(-offset) [expr {-$data(-max)*$yscale}]
}

proc ::spectrum::update {w xy} {
    upvar #0 ::spectrum::$w data
    $w coords spectrum $xy
    ::spectrum::scale $w spectrum
    # keep older copies fading to black?
}

proc ::spectrum::configure {w args} {
    upvar #0 ::spectrum::$w data
    array set save [array get data]
    foreach {option value} $args {
	switch -- $option {
	    -scale -
	    -offset {
		set adjust 1
		set data($option) $value
	    }
	    -min -
	    -max {
		set adjust 1
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
    if {[info exists adjust]} {
	catch {$w delete grid}
	set dark \#888
	set med \#AAA
	set light \#CCC
	set lo [expr {-double([winfo width $w])/$data(-scale)/2.0}]
	set hi [expr {-$lo}]
	#puts "scale $data(-scale) offset $data(-offset) width [winfo width $w], $lo .. $hi"
	for {set l $data(-min)} {$l <= $data(-max)} {incr l 20} {
	    # main db grid
	    $w create line $lo $l $hi $l -fill $dark -tags grid
	    $w create text $lo $l -text "$l dB" -anchor nw -fill $dark -tags grid
	    # sub grid
	    if {0} {
		for {set ll [expr {$l-10}]} {$ll > $l-20} {incr ll -10} {
		    if {$ll >= $data(-min) && $ll <= $data(-max)} {
			$w create line $lo $ll $hi $ll -fill $med -tags grid
		    }
		}
	    }
	}
	$w lower grid
	::spectrum::scale $w grid
    }
}

proc ::spectrum::defaults {} {
    return [array get ::spectrum::default_data]
}

proc ::spectrum::spectrum {w args} {
    upvar #0 ::spectrum::$w data
    array set data [::spectrum::defaults]
    array set data $args
    canvas $w -height $data(-height) -bg black
    $w create line 0 0 0 0 -fill white -tags spectrum
    return $w
}    

proc ::spectrum {w args} {
    return [::spectrum::spectrum $w {*}$args]
}
