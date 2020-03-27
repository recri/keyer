# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA
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
package provide sdrtcl::hl-bandscope 0.0.1

package require Thread
package require snit

namespace eval ::sdrtcl {}

# hl-bandscope-thread - hermes-lite bandscope background sample manager
#
snit::type sdrtcl::hl-bandscope-thread {
}

#
# hl-bandscope - hermes-lite bandscope foreground sample manager
#
snit::type sdrtcl::hl-bandscope {
    constructor {args} {
	if {0} {
	    set id [thread::create -joinable -preserved]
	    thread::send $id [list lappend auto_path ~/keyer/lib]
	    thread::send $id [list package require sdrtcl::hl-bandscope]
	    thread::send $id [list sdrtcl::hl-bandscope-thread $name {*}$args]
	}
    }
    destructor {
	if {0} {
	    while {[thread::release $id] > 0} {}
	    thread::join $id
	}
    }
    method samples {buffer} {}
}



