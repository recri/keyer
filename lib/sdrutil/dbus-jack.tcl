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

package provide dbus-jack 1.0

package require dbus-tcl

namespace eval ::dbus-jack:: {
}

if { ! [info exists ::dbus-jack::signals]} {
    array set ::dbus-jack::signals {}
    dbus filter add -type signal -path /org/jackaudio/Controller
    foreach member {ServerStarted ServerStopped ClientAppeared ClientDisappeared GraphChanged
	PortAppeared PortDisappeared PortRenamed PortsConnected PortsDisconnected StateChanged} {
	set ::dbus-jack::signals($member) {}
	dbus listen /org/jackaudio/Controller $member ::dbus-jack::jack-signal
    }
    #puts [array get ::dbus-jack::signals]
}

proc ::dbus-jack::jack-signal {dict args} {
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

proc ::dbus-jack::jack-listen {member script} {
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

proc ::dbus-jack::jack-call {interface method {sig {}} args} {
    return [dbus call session -dest org.jackaudio.service -signature $sig /org/jackaudio/Controller org.jackaudio.$interface $method {*}$args]
}

#
# interfaces
#
proc ::dbus-jack::jack-control {method {sig {}} args} { return [jack-call JackControl $method $sig {*}$args] }
proc ::dbus-jack::jack-configure {method {sig {}} args} { return [jack-call Configure $method $sig {*}$args] }
proc ::dbus-jack::jack-patchbay {method {sig {}} args} { return [jack-call JackPatchbay $method $sig {*}$args] }
proc ::dbus-jack::session-manager {method {sig {}} args} { return [jack-call SessionManager $method $sig {*}$args] }

#
# method calls
#

# interface org.jackaudio.JackControl
proc ::dbus-jack::add-slave-driver {driver_name} { return [jack-control AddSlaveDriver s $driver_name] }
proc ::dbus-jack::get-buffer-size {} { return [jack-control GetBufferSize] }
proc ::dbus-jack::get-latency {} { return [jack-control GetLatency] }
proc ::dbus-jack::get-load {} { return [jack-control GetLoad] }
proc ::dbus-jack::get-sample-rate {} { return [jack-control GetSampleRate] }
proc ::dbus-jack::get-xruns {} { return [jack-control GetXruns] }
proc ::dbus-jack::is-realtime {} { return [jack-control IsRealtime] }
proc ::dbus-jack::is-started {} { return [jack-control IsStarted] }
proc ::dbus-jack::load-internal {internal} { return [jack-control LoadInternal s $internal] }
proc ::dbus-jack::remove-slave-driver {driver_name} { return [jack-control RemoveSlaveDriver s $driver_name] }
proc ::dbus-jack::reset-xruns {} { return [jack-control ResetXruns] }
proc ::dbus-jack::set-buffer-size {frames} { return [jack-control SetBufferSize u $frames] }
proc ::dbus-jack::start-server {} { return [jack-control StartServer] }
proc ::dbus-jack::stop-server {} { return [jack-control StopServer] }
proc ::dbus-jack::switch-master {} { return [jack-control SwitchMaster] }
proc ::dbus-jack::unload-internal {internal} { return [jack-control UnloadInternal s $internal] }

# interface org.jackaudio.Configure
proc ::dbus-jack::get-parameter-constraint {parameter} { return [jack-configure GetParameterConstraint as $parameter] }
proc ::dbus-jack::get-parameter-info {parameter} { return [jack-configure GetParameterInfo as $parameter] }
proc ::dbus-jack::get-parameter-value {parameter} { return [jack-configure GetParameterValue as $parameter] }
proc ::dbus-jack::get-parameters-info {parent} { return [jack-configure GetParametersInfo as $parent] }
proc ::dbus-jack::read-container {parent} { return [jack-configure ReadContainer as $parent] }
proc ::dbus-jack::reset-parameter-value {parameter} { return [jack-configure ResetParameterValue as $parameter] }
proc ::dbus-jack::set-parameter-value {parameter value} { return [jack-configure SetParameterValue asv $parameter $value] }

# interface org.jackaudio.JackPatchbay
proc ::dbus-jack::connect-ports-by-id {port1 port2} {    return [jack-patchbay ConnectPortsByID tt $port1 $port2] }
proc ::dbus-jack::connect-ports-by-name {client1 port1 client2 port2} {    return [jack-patchbay ConnectPortsByID ssss $client1 $port1 $client2 $port2] }
proc ::dbus-jack::disconnect-ports-by-connection-id {id} {    return [jack-patchbay DisonnectPortsByConnectionID t $id] }
proc ::dbus-jack::disconnect-ports-by-id {port1 port2} {    return [jack-patchbay DisconnectPortsByID tt $port1 $port2] }
proc ::dbus-jack::disconnect-ports-by-name {client1 port1 client2 port2} {    return [jack-patchbay DisconnectPortsByName ssss $client1 $port1 $client2 $port2] }
proc ::dbus-jack::get-all-ports {} { return [jack-patchbay GetAllPorts] }
proc ::dbus-jack::get-client-PID {client} { return [jack-patchbay GetClientPID t $client] }
proc ::dbus-jack::get-graph {version} { return [jack-patchbay GetGraph t $version] }

# interface org.jackaudio.SessionManager
proc ::dbus-jack::get-client-name-by-UUID {uuid} { return [session-manager GetClientNameByUuid s $uuid] }
proc ::dbus-jack::get-state {} { return [session-manager GetState] }
proc ::dbus-jack::get-UUID-for-client-name {name} { return [session-manager GetUuidForClientName s $name] }
proc ::dbus-jack::has-session-callback {name} { return [session-manager HasSessionCallback s $name] }
proc ::dbus-jack::notify {queue target type path} { return [session-manager Notify bsus $queue $target $type $path] }
proc ::dbus-jack::reserve-client-name {name uuid} { return [session-manager ReserveClientName ss $name $uuid] }

# usual parameters from start-jack
proc ::dbus-jack::set-driver {driver} { set-param engine driver $driver }
proc ::dbus-jack::set-driver-param {param value} { set-param driver $param $value }
proc ::dbus-jack::set-internal-param {internal param value} { set-param $internal $param $value }
proc ::dbus-jack::set-param {which param value} {
    switch $param {
	driver -
	device -
	playback -
	capture -
	midi-driver {
	    set-parameter-value [concat $which $param] [list {s} $value]
	}
	rate {
	    set-parameter-value [concat $which $param] [list {u} $value]
	}
	default {
	    error "unknown $which parameter $param"
	}
    }
}
