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
package provide midiscope 1.0.0

namespace eval ::midiscope {}

proc midiscope::start-taps {w} {
    ::sdrkit::mtap key_tap
    ::sdrkit::mtap keyer_tap
    ::sdrkit::jack connect system:midi_capture_1 key_tap:midi_in
    ::sdrkit::jack connect iambic:midi_out keyer_tap:midi_in
}

proc midiscope::start {w} {
    upvar #0 $w data
    set data(start-frame) [sdrkit::jack frame-time]
    set data(sample-rate) [sdrkit::jack sample-rate]
    $w.m.start configure -state disabled
    $w.m.stop configure -state normal
    key_tap start
    keyer_tap start
    foreach name {key-0 key-0-xy key-1 key-1-xy keyer-0 keyer-0-xy} {
	set data($name) {}
    }
    midiscope::collect $w
}

proc midiscope::stop {w} {
    upvar #0 $w data
    $w.m.start configure -state normal
    $w.m.stop configure -state disabled
    $w.m.clear configure -state normal
    catch {after cancel $data(token)}
}

proc midiscope::clear {w} {
    upvar #0 $w data
    $w.m.clear configure -state disabled
    foreach name {key_tap keyer_tap} {
	foreach note {0 1} {
	    if {[info exists data($name-$note-xy)]} {
		$w.c coords $name-$note {0 0 0 0}
		set data($name-$note-xy) {}
	    }
	}
    }
}

proc midiscope::collect {w} {
    upvar #0 $w data
    foreach name {key_tap keyer_tap} {
	foreach item [$name get] {
	    foreach {time bdata} $item break
	    set time [expr {double($time-$data(start-frame))/$data(sample-rate)}]
	    binary scan $bdata c* cdata
	    if {[llength $cdata] == 3} {
		foreach {cmd note vel} $cdata break
		if {($cmd&0xff) == 0x80} {
		    lappend data($name-$note-xy) $time 1 $time 0
		} else {
		    lappend data($name-$note-xy) $time 0 $time 1
		}
	    }
	}
    }
    foreach name {key_tap keyer_tap} {
	foreach note {0 1} {
	    if {[info exists data($name-$note-xy)] && [llength $data($name-$note-xy)] > 3} {
		$w.c coords $name-$note $data($name-$note-xy)
	    }
	}
    }

    set cht [winfo height $w.c]
    # scale time as data(x-scale), traces to 1/16 window height
    $w.c scale all 0 0 $data(x-scale) [expr {-$cht/32}]
    # spread out the key and keyer traces vertically
    $w.c move keyer_tap-0 0 [expr {4*$cht/8}]
    $w.c move key_tap-0 0 [expr {6*$cht/8}]
    $w.c move key_tap-1 0 [expr {8*$cht/8}]
    # reset the scroll region
    $w.c configure -scrollregion [$w.c bbox all]
    # keep the front in view
    foreach {l r} [$w.c xview] break
    # puts "xview $l $r"
    $w.c xview moveto [expr {$l+(1-$r)}]
    # come around for another bite
    set data(token) [after 100 [list midiscope::collect $w]]
}

proc midiscope::x-rescale {w} {
    upvar #0 $w data
    
    if { ! [info exists data(x-scale)]} {
	set data(x-scale) [$w.m.time get]
    } else {
	set new [$w.m.time get]
	set old $data(x-scale)
	$w.c scale all 0 0 [expr {$new/$old}] 1
	set data(x-scale) $new
	# reset the scroll region
	$w.c configure -scrollregion [$w.c bbox all]
    }
}

proc midiscope::x-scales {w} {
    return {1e0 2.5e0 5e0 1e1 2.5e1 5e1 1e2 2.5e2 5e2 1e3 2.5e3 5e3 1e4 2.5e4 5e4 1e5 2.5e5 5e5 1e6 2.5e6 5e6 1e7 2.5e7 5e7 1e8 2.5e8 5e8 1e9 2.5e9 5e9 1e10} 
}

proc midiscope {w} {
    ::midiscope::start-taps $w
    ttk::frame $w
    grid [ttk::frame $w.m] -row 0 -column 0
    pack [ttk::button $w.m.start -text {Start Capture} -state normal -command [list midiscope::start $w]] -side left
    pack [ttk::button $w.m.stop -text {Stop Capture} -state disabled -command [list midiscope::stop $w]] -side left
    pack [ttk::button $w.m.clear -text {Clear} -state disabled -command [list midiscope::clear $w]] -side left
    pack [ttk::spinbox $w.m.time -values [midiscope::x-scales $w] -command [list midiscope::x-rescale $w]] -side left
    $w.m.time set 1e1
    midiscope::x-rescale $w
    #pack [ttk::button $w.m.quit -text {Quit} -command quit] -side right
    grid [canvas $w.c] -row 1 -column 0 -sticky nsew
    grid [ttk::scrollbar $w.v] -row 1 -column 1 -sticky ns
    grid [ttk::scrollbar $w.h -orient horizontal] -row 2 -column 0 -sticky ew
    grid columnconfigure $w 0 -weight 100
    grid rowconfigure $w 1 -weight 100
    $w.c configure -xscrollcommand [list $w.h set]
    $w.c configure -yscrollcommand [list $w.v set]
    $w.h configure -command [list $w.c xview]
    $w.v configure -command [list $w.c yview]
    $w.c create line 0 0 0 0 -tags key_tap-0
    $w.c create line 0 0 0 0 -tags key_tap-1
    $w.c create line 0 0 0 0 -tags keyer_tap-0
    return $w
}

