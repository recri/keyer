# -*- mode: Tcl; tab-width: 8; -*-
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

#
# the startup manager
#
package provide sdrkit::startup 1.0.0

package require snit
package require sdrkit::startup-usb
package require sdrkit::startup-alsa
package require sdrkit::startup-jack
package require sdrkit::startup-jconn

namespace eval sdrkit {}

snit::type sdrkit::startup {

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    constructor {args} {
	$self configure {*}$args
	pack [ttk::notebook .tab] -fill both -expand true
	foreach item {usb alsa jack jack-details jack-connections app} {
	    .tab add [$self $item-panel .tab.$item -container $self] -text $item
	    $self $item-update .tab.$item
	}
    }

    destructor { }

    method configure {args} {
	foreach {opt val} $args {
	    set options($opt) $val
	}
    }

}

