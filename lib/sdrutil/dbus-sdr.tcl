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

package provide dbus-sdr 1.0

package require dbus
package require dbus-jack

namespace eval ::dbus-sdr:: {
}

#
# gad, dbus is so confusing
# the name/address of our service is org.sdrkit.service
# the object path is /org/sdrkit/Controller
# the interface is org.sdrkit.Control
# 
if { ! [info exists ::dbus-sdr::signals]} {
    if {[catch {dbus name -replace org.sdrkit.service} error]} {
	# we are not the owner of the name, but we may become owner at some point
	puts "failed, do not own org.sdrkit.service"
    } else {
	# we are the owner of the name
	puts "succeeded, own org.sdrkit.service"
    }
    array set ::dbus-sdr::signals {}
    dbus filter add -type signal -path /org/sdrkit/Controller
    foreach member {Connect Disconnect Register Deregister Message} {
	set ::dbus-sdr::signals($member) {}
	dbus listen /org/sdrkit/Controller $member ::dbus-sdr::handler
    }
    #puts [array get ::dbus-sdr::signals]
}

proc ::dbus-sdr::handler {dict args} {
    variable signals
    set member [dict get $dict member]
    catch {log "signal $member received"}
    foreach handler $signals($member) {
	if {[catch {{*}$handler $dict {*}$args} error]} {
	    set index [lsearch $signals($member) $handler]
	    if {$index >= 0} {
		set signals($member) [lreplace $signals($member) $index $index]
	    }
	    catch {log "removing dbus-sdr::signal $handler from $member signal handling: $error"}
	}
    }
}

proc ::dbus-sdr::listen {member script} {
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

proc ::dbus-sdr::call {interface method {sig {}} args} {
    return [dbus call session -dest org.sdrkit.service -signature $sig /org/sdrkit/Controller org.sdrkit.$interface $method {*}$args]
}

proc ::dbus-sdr::signal {member} {
    return [dbus signal session /org/sdrkit/Controller org.sdrkit.Control $member]
}

#
# interfaces
#
proc ::dbus-sdr::control {method {sig {}} args} { return [call Control $method $sig {*}$args] }

#
# signal/listener test
#
proc ::dbus-sdr::start-listeners {} {
    variable signals
    foreach s [array names signals] {
	listen $s ::dbus-sdr::dummy-handler
    }
}

proc ::dbus-sdr::dummy-handler {dict args} {
    puts stderr "[dict get $dict member] $args"
}

proc ::dbus-sdr::dummy-life-cycle {} {
    variable signals
    foreach s [array names signals] {
	puts "signal $s: [signal $s]"
	after 500
    }
}

#
# the application life cycle follows the jack server.
# when the jack server is stopped, then all the dsp and midi components are stopped.
# when the jack server starts, then the components can register, activate, and create ports.
# when all the ports are created, then the ports can be connected
# 
proc ::dbus-sdr::manage-life-cycle {} {
}
