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

package provide mouse-key 1.0.0

package require Tk
package require sdrkit::midi-insert

# implement a key on mouse buttons or key presses

namespace eval ::mouse-key {
    array set default_data {
	-server default
	-name mouse-key
	-chan 1
	-note 0
	midi-note-off 0x80
	midi-note-on 0x90
    }
}

namespace eval ::mouse-key::cmd {}

proc ::mouse-key::note-on {w n} {
    upvar #0 ::mouse-key::$w data
    $data(insert) puts [binary format ccc [expr {$data(midi-note-on)|($data(-chan)-1)}] [expr {$data(-note)+($n&1)}] 0]
}

proc ::mouse-key::note-off {w n} {
    upvar #0 ::mouse-key::$w data
    $data(insert) puts [binary format ccc [expr {$data(midi-note-off)|($data(-chan)-1)}] [expr {$data(-note)+($n&1)}] 0]
}

proc ::mouse-key::shutdown {w wd} {
    if {$w eq $wd} {
	upvar #0 ::mouse-key::$w data
	rename $data(insert) {}
    }
}

proc ::mouse-key::defaults {} {
    return [array get ::mouse-key::default_data]
}

proc ::mouse-key::mouse-key {w args} {
    upvar #0 ::mouse-key::$w data
    array set data [::mouse-key::defaults]
    foreach {option value} $args {
	switch -- $option {
	    -name - --name { set data(-name) $value }
	    -server - -s - --server { set data(-server) $value }
	    -chan - -c - --channel { set data(-chan) $value }
	    -note - -n - --note { set data(-note) $value }
	    default { error "unknown option \"$option\"" }
	}
    }
    set data(insert) ::mouse-key::cmd::$data(-name)
    sdrkit::midi-insert $data(insert) -server $data(-server)
    if {[winfo toplevel $w] eq $w} {
	wm title $w $data(-name)
    }
    if {$w eq {.}} {
	set c .c
    } else {
	set c $w.c
    }
    pack [canvas $c] -fill both -expand true
    bind $c <ButtonPress-1> [list ::mouse-key::note-on $w 0]
    bind $c <ButtonRelease-1> [list ::mouse-key::note-off $w 0]
    bind $c <ButtonPress-3> [list ::mouse-key::note-on $w 1]
    bind $c <ButtonRelease-3> [list ::mouse-key::note-off $w 1]
    focus $c
    bind $c <KeyPress> [list ::mouse-key::note-on $w %N]
    bind $c <KeyRelease> [list ::mouse-key::note-off $w %N]
    bind $w <Destroy> [list ::mouse-key::shutdown $w %W]
    return $w
}

proc ::mouse-key {w args} {
    return [::mouse-key::mouse-key $w {*}$args]
}
