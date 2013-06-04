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
# dbus upstart listens to the system bus for device additions/removals
#

package provide dbus-upstart 1.0

package require dbus

namespace eval ::dbus-upstart:: {
}

if { ! [info exists ::dbus-upstart::signals]} {
    dbus connect system
    array set ::dbus-upstart::signals {}
    dbus filter system add -type signal -path /com/ubuntu/Upstart
    foreach member {EventEmitted} {
	set ::dbus-upstart::signals($member) {}
	dbus listen system /com/ubuntu/Upstart $member ::dbus-upstart::signal
    }
}

proc ::dbus-upstart::signal {dict args} {
    variable signals
    set member [dict get $dict member]
    catch {log "signal $member received"}
    foreach handler $signals($member) {
	if {[catch {{*}$handler $dict {*}$args} error]} {
	    set index [lsearch $signals($member) $handler]
	    if {$index >= 0} {
		set signals($member) [lreplace $signals($member) $index $index]
	    }
	    catch {log "removing $handler from $member signal handling: $error"}
	}
    }
}

proc ::dbus-upstart::listen {member script} {
    variable signals
    set index [lsearch $signals($member) $script]
    if {$index >= 0} {
	# remove
	set signals($member) [lreplace $signals($member) $index $index]
    } else {
	# append
	lappend signals($member) $script
    }
}


