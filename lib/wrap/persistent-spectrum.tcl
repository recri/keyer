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
package provide persistent-spectrum 1.0.0

package require Tk
package require hotiron

##
## common parts to waterfall and hurricane
##

namespace eval ::persistent-spectrum {
    array set default_data {
	-rows 1
	-atten 0
	-pal 0
	-min -125.0
	-max -60.0
	-min-f -1e6
	-max-f 1e6
	-reverse 0
    }
}

##
## compute a pixel value for the specified level using the configured palette
##
proc ::persistent-spectrum::pixel {w level} {
    upvar #0 ::persistent-spectrum::$w data
    # clamp to percentage of range
    set level [expr {min(1,max(0,($level-$data(-min))/($data(-max)-$data(-min))))}]
    # use 100 levels
    set i color-$data(-pal)-[expr {int(100*$level)}]
    if { ! [info exists data($i)]} {
	set data($i) [::hotiron $level $data(-pal)]
    }
    return $data($i)
}

##
## make a row or column of pixel values
##
proc ::persistent-spectrum::scan {w xy} {
    upvar #0 ::persistent-spectrum::$w data
    set freq {}
    set scan {}
    foreach {x y} $xy {
	if {$x >= $data(-min-f) && $x <= $data(-max-f)} {
	    lappend freq $x
	    if {$data(-rows)} {
		lappend scan [pixel $w [expr {$y+$data(-atten)}]]
	    } else {
		lappend scan [list [pixel $w [expr {$y+$data(-atten)}]]]
	    }
	}
    }
    if {$data(-reverse)} {
	set freq [lreverse $freq]
	set scan [lreverse $scan]
    }
    if {$data(-rows)} {
	return [list $freq [list $scan]]
    } else {
	return [list $freq $scan]
    }
}

##
## default configuration
##
proc ::persistent-spectrum::defaults {} {
    return [array get ::persistent-spectrum::default_data]
}

##
## cleanup your mess
##
proc ::persistent-spectrum::destroy {w} {
    upvar #0 ::persistent-spectrum::$w data
    foreach img [array names data img-*] {
	rename $data($img) {}
    }
    array unset data
}

##
## configure
##
proc ::persistent-spectrum::configure {w args} {
    upvar #0 ::persistent-spectrum::$w data
    array set data $args
}

##
## make an instance, namespace local
##
proc ::persistent-spectrum::persistent-spectrum {w args} {
    upvar #0 ::persistent-spectrum::$w data
    ::persistent-spectrum::configure $w {*}[::persistent-spectrum::defaults]
    ::persistent-spectrum::configure $w {*}$args
    return $w
}

##
## make an instance, public
##
proc ::persistent-spectrum {w args} {
    return [::persistent-spectrum::persistent-spectrum $w {*}$args]
}

