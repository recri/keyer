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
package provide wrap 1.0.0

package require Tk

namespace eval ::wrap {}
namespace eval ::wrap::cmd {}

#
# common cleanup
#
proc ::wrap::cleanup {bw w} {
    # puts "cleanup $bw $w"
    if {$bw eq $w} {
	upvar #0 $w data
	if {[info exists data(cleanup-after)]} {
	    # puts "cleanup $data(cleanup-after)"
	    after cancel $data(cleanup-after)
	}
	if {[info exists data(cleanup-func)]} {
	    foreach f $data(cleanup-func) {
		rename $f {}
	    }
	}
	unset data
    }
}

proc ::wrap::cleanup_bind {w} {
    upvar #0 $w data
    if { ! [info exists data(cleanup-bound)]} {
	# puts "cleanup_bind $w"
	bind $w <Destroy> [list ::wrap::cleanup %W $w]
	set data(cleanup-bound) 1
    }
}
    
proc ::wrap::cleanup_func {w func} {
    upvar #0 $w data
    # puts "cleanup_func $w $func"
    lappend data(cleanup-func) $func
    cleanup_bind $w
}

proc ::wrap::cleanup_after {w after} {
    upvar #0 $w data
    # puts "cleanup_after $w $after"
    set data(cleanup-after) $after
    cleanup_bind $w
}

proc ::wrap::default_window {w} {
    if { ! [winfo exists $w] } { ttk::frame $w }
}

#
# generate a binary string with $n floating point numbers
#
proc ::wrap::make_binary {n} {
    return [binary format f* [lrepeat n 0.0]]
}

