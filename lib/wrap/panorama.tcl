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
## panorama - combined spectrum, waterfall, and frequency display
##
package provide panorama 1.0.0

package require sdrkit::jack

package require waterfall
package require spectrum
package require frequency
package require capture

namespace eval ::panorama {
    array set default_data {
	-zoom 1.0
	-scroll 0.0
	-connect {}
	-period 50
	-size 4096
    }
}

proc ::panorama::update {w xy} {
    upvar #0 ::panorama::$w data
    # update spectrum and waterfall
    ::spectrum::update $w.s $xy
    ::waterfall::update $w.w $xy
    ::frequency::update $w.f $xy
}

proc ::panorama::configure {w args} {
    upvar #0 ::panorama::$w data
    foreach {option value} $args {
	switch -- $option {
	    default { set data($option) $value 	}
	}
    }
}

proc ::panorama::window-configure {w cw width height} {
    if {$w ne $cw} return
    # puts "panorama::window-configure $w $cw $width $height"
    upvar #0 ::panorama::$w data
    ::capture::configure $w -size $width
    set srate [sdrkit::jack sample-rate]
    set scale [expr {$data(-zoom)*double($width)/$srate}]
    set offset [expr {double($width)/2}]
    ::waterfall::configure $w.w -scale $scale -offset $offset
    ::spectrum::configure $w.s -scale $scale -offset $offset
    ::frequency::configure $w.f -scale $scale -offset $offset
}

proc ::panorama::window-destroy {w cw} {
    if {$w ne $cw} return
    upvar #0 ::panorama::$w data
    ::capture::destroy $w
    ::waterfall::destroy $w.w
    ::spectrum::destroy $w.s
    ::frequency::destroy $w.f

    foreach img [array names data img-*] {
	rename $data($img) {}
    }
}

proc ::panorama::panorama {w args} {
    upvar #0 ::panorama::$w data
    array set data [array get ::panorama::default_data]
    array set data $args
    ttk::panedwindow $w -orient vertical
    $w add [::spectrum $w.s] -weight 1
    $w add [::frequency $w.f] -weight 0
    $w add [::waterfall $w.w] -weight 1
    #rename $w ::panorama::$w
    #proc $w {args} [list return [list panorama::command $w \$args]]
    ::capture::spectrum $w -period $data(-period) -size $data(-size) -client ::panorama::update
    bind . <Configure> [list ::panorama::window-configure $w %W %w %h]
    bind . <Destroy> [list ::panorama::window-destroy $w %W]
    return $w
}

proc ::panorama::defaults {} {
    return [array get ::panorama::default_data]
}

proc ::panorama {w args} {
    return [panorama::panorama $w {*}$args]
}
