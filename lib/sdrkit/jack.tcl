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

package provide sdrkit::jack 1.0.0

package require sdrkit::jack-client

namespace eval ::sdrkit {
    if {[info exists ::env(JACK_SERVER)]} {
	set jack(default) [sdrkit::jack-client jack-$::env(JACK_SERVER)-[pid] -server $::env(JACK_SERVER)]
    } else {
	set jack(default) [sdrkit::jack-client jack-default-[pid]]
    }
}

proc ::sdrkit::jack {args} {
    set server default
    switch -- [lindex $args 0] {
	-server {
	    set server [lindex $args 1]
	    set args [lrange $args 2 end]
	    if { ! [info exists ::sdrkit::jack($server)]} {
		set ::sdrkit::jack($server) [sdrkit::jack-client jack-$server-[pid] -server $server]
	    }
	}
    }
    return [$::sdrkit::jack($server) {*}$args]
}
