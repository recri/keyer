# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2014 by Roger E Critchlow Jr, Santa Fe, NM, USA.
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

package provide ladish 1.0

# prepare to dbus
package require dbus
package require dbif

namespace eval ::ladish:: {
    # initialize data
    array set data { present {} monitor {} dict {} }
}

# dbus/dbif helpers
proc sdrkit-dbus-ping {name} {
    return [dbus call $name org.freedesktop.DBus.Peer Ping]
}
proc sdrkit-dbus-introspect {name} {
    return [dbus call -dest org.sdrkit.$name / org.freedesktop.DBus.Introspectable Introspect]
}
proc sdrkit-dbus-get-all {name} {
    return [dbus call -dest org.sdrkit.$name / org.freedesktop.DBus.Properties GetAll org.sdrkit.Bus]
}
proc sdrkit-dbus-get-value {name key} {
    return [dbus call -dest org.sdrkit.$name / org.freedesktop.DBus.Properties Get org.sdrkit.Bus $key]
}
proc sdrkit-dbus-set-value {name key value} {
    return [dbus call -dest org.sdrkit.$name / org.freedesktop.DBus.Properties Set org.sdrkit.Bus $key $value]
}
proc sdrkit-dbus-listen {path interface member script} {
    if {$path eq {}} {
	dbus filter add -type signal -interface $interface -member $member
    } else {
	dbus filter add -type signal -path $path -interface $interface -member $member
    }
    dbus listen $path $interface.$member $script
}
proc sdrkit-dbus-call {name method args} {
    return [dbus call -dest org.sdrkit.$name / org.sdrkit.Bus $method $args]
}


proc ladish-start-rollcall {} {
    # puts "[clock milliseconds]: ladish-start-rollcall"
    # initialize the list of responders and monitor log
    array set ::ladish::data {present {} monitor {}}
    # announce roll call
    # puts "[clock milliseconds] put org.sdrkit.Bus.RollCall()"
    dbus signal / org.sdrkit.Bus RollCall
    # start monitor
    after 250 [list ladish-monitor-rollcall]
}

#
# listen for responses to roll call
# until the list stabilizes, then
# find out what the components can do
#
proc ladish-monitor-rollcall {} {
    # see how many components have reported
    set n [llength $::ladish::data(present)]
    # remember this outcome
    lappend ::ladish::data(monitor) $n
    # see if it's stable
    if {[llength [lsearch -all -exact $::ladish::data(monitor) $n]] < 5} {
	# puts "[clock milliseconds] ladish-monitor-rollcall go around again: $::ladish::data(monitor)"
	# still stabilizing
	after 100 [list ladish-monitor-rollcall]
    } else {
	# one quarter second at this level of response
	set ::ladish::data(present) [lsort $::ladish::data(present)]
	# puts "[clock milliseconds] ladish-monitor-rollcall install $::ladish::data(present)"
	# puts "updating components to $::ladish::data(present)"
	set d [dict create]
	foreach name [lsort $::ladish::data(present)] {
	    # puts "[clock milliseconds] [sdrkit-dbus-introspect $name]"
	    set p [dict create]
	    foreach {key value} [sdrkit-dbus-get-all $name] {
		dict set p $key $value
		# puts "$key @ $name -> [sdrkit-dbus-get-value $name $key]"
	    }
	    dict set d $name $p
	    # puts "[clock milliseconds] $name info command = {[sdrkit-dbus-call $name Component info command]}"
	    # puts "[clock milliseconds] $name info methods = {[sdrkit-dbus-call $name Component info methods]}"
	    # puts "[clock milliseconds] $name info options = {[sdrkit-dbus-call $name Component info options]}"
	    # foreach opt [sdrkit-dbus-call $name Component info options] {
	    #	 puts "[clock milliseconds] $name info option $opt = {[sdrkit-dbus-call $name Component info option $opt]}"
	    # }
	}
	set ::ladish::data(dict) $d
	if {$::ladish::data(callback) ne {}} {
	    catch {$::ladish::data(callback) $d}
	}

	#dict for {name value} $d {
	#    puts "[clock milliseconds] $name [dict keys $value]"
	#}
    }
}

proc ladish-signal-received {name dict args} {
    #puts "[clock milliseconds] ladish-signal-received $name $args"
    catch {after cancel $::ladish::data(after)}
    set ::ladish::data(after) [after 250 ladish-start-rollcall]
}
    
proc sdrkit-ladish-connect {{callback {}}} {
    set ::ladish::data(callback) $callback
    ## connect to the bus
    dbif default -bus session -interface org.sdrkit.Bus
    dbif connect -replace -yield org.sdrkit.bus

    ## listen for name replacement
    ## NB, don't know if this works or not, never tried
    dbif listen -interface org.freedesktop.DBus /org/freedesktop/DBus NameLost { exit }

    ## listen for the responses to the roll call
    dbif listen -interface org.sdrkit.Bus / Present name {
	# puts "[clock milliseconds] org.sdrkit.Bus.Present($name)"
	lappend ::ladish::data(present) $name
    }

    #
    # poll for components
    # after all changes have settled
    #
    foreach member {AppAdded AppRemoved AppStateChanged} {
	sdrkit-dbus-listen {} org.ladish.AppSupervisor $member [list ladish-signal-received $member]
	sdrkit-dbus-listen {} org.ladish.AppSupervisor ${member}2 [list ladish-signal-received ${member}2]
    }    
    
    ## schedule the first roll call
    set ::ladish::data(after) [after 250 [list ladish-start-rollcall]]
}

proc sdrkit-ladish-status {} {
    return $::ladish::data(dict)
}

