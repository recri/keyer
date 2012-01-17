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
package provide hurricane 1.0.0

package require Tk
package require persistent-spectrum

##
## hurricane
##

namespace eval ::hurricane {
    array set default_data {
	-rows 0
	-reverse 1
	-height 200
	-atten 0
	-pal 0
	-min -125.0
	-max -60.0
    }
}

proc ::hurricane::update {w xy} {
    upvar #0 ::hurricane::$w data

    # compute the scan line of pixels
    foreach {freq scan} [::persistent-spectrum::scan $w $xy] break
	
    # scroll all the images left by 1
    $w move all -1 0

    # create a new canvas image
    set i $data(line-number)
    set data(img-$i) [image create photo]
    $data(img-$i) put $scan
    set data(item-$i) [$w create image [expr {[winfo width $w]-1}] 0 -anchor ne -image $data(img-$i) -tags img-$i]
    $w lower $data(item-$i)

    # increment our scanline index
    incr data(line-number)

    # discard off screen images
    foreach i [$w find overlapping -10000 0 0 100] {
	# delete image
	catch {rename $data([$w gettags $i]) {}}
	# delete canvas item
	catch {$w delete $i}
    }
}

proc ::hurricane::destroy {w} {
    upvar #0 ::hurricane::$w data
    ::persistent-spectrum::destroy $w
    foreach img [array names data img-*] {
	rename $data($img) {}
    }
    array unset data
}

proc ::hurricane::configure {w args} {
    upvar #0 ::hurricane::$w data
    if {$args eq {}} {
	return [array get data]
    }
    array set save [array get data]
    foreach {option value} $args {
	switch -- $option {
	    -pal -
	    -rows -
	    -atten -
	    -pal -
	    -min -
	    -max -
	    -min-f -
	    -max-f -
	    -reversed {
		::persistent-spectrum::configure $w $option $value
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
}
    
proc ::hurricane::defaults {} {
    return [array get ::hurricane::default_data]
}

proc ::hurricane::hurricane {w args} {
    upvar #0 ::hurricane::$w data
    ::persistent-spectrum $w
    ::hurricane::configure $w {*}[::hurricane::defaults]
    ::hurricane::configure $w {*}$args
    canvas $w -height $data(-height) -bg black
    set data(line-number) 0
    return $w
}

proc ::hurricane {w args} {
    return [::hurricane::hurricane $w {*}$args]
}

