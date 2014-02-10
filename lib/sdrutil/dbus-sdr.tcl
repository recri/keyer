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

package require dbus-tcl
package require dbus-jack

namespace eval ::dbus-sdr:: {
    set service {org.sdrkit.service}
    set object {/org/sdrkit/Service}
    set interface {org.sdrkit.Service}

    set owner {}
    set serial 0
    set pnodes {}

    set verbose 5
    set replies {}
}

proc ::dbus-sdr::owner {} {
    variable owner
    return $owner
}

proc ::dbus-sdr::random-byte {} {
    set b {0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ}
    set n [string length $b]
    return [string index $b [expr {int(rand()*$n)}]]
}

proc ::dbus-sdr::add-pnode-addr {addr} {
    variable pnodes
    if { ! [find-pnode-addr $addr]} { lappend pnodes $addr }
}

proc ::dbus-sdr::find-pnode-addr {addr} {
    variable pnodes
    return [expr {[lsearch $pnodes $addr] >= 0}]
}

proc ::dbus-sdr::pick-pnode-addr {} {
    variable addr
    for {set a [random-byte]} {[find-pnode-addr $a]} {set a [random-byte]} {}
    set addr $a
    log 5 "pick-pnode-addr chooses {$addr}"
}
    
proc ::dbus-sdr::log {level msg} {
    variable verbose
    if {$verbose >= $level} { catch { ::log $msg } }
}

proc ::dbus-sdr::join-request {} {
    variable signals;		# array of signal handlers
    variable owner;		# owner of org.sdrkit.service or not
    variable joined;		# have successfully joined the group
    variable addr;		# proposed or accepted address of joining
    variable serial;		# running serial number for messages
    variable timeout;		# after handler cookie
    variable jserial;		# serial number of our join request

    if { ! [info exists signals]} {
	# stage 1 -- no signals array
	# connect to dbus sdrkit service
	if {[catch {dbus name org.sdrkit.service} error]} {
	    # we are not the owner of the name, but we may become owner at some point
	    set owner false
	    log 1 "client of org.sdrkit.service"
	} else {
	    # we are the owner of the name
	    set owner true
	    log 1 "owner of org.sdrkit.service"
	}
	# stage 1a -- initialize signal handler array
	array set signals {}
	dbus filter add -type signal -path /org/sdrkit/Service
	# Connect Disconnect Register Deregister 
	foreach member {Join Message} {
	    set signals($member) {}
	    dbus listen /org/sdrkit/Service $member ::dbus-sdr::signal-handler
	}
	# stage 1b -- start our join handler
	listen-for Join ::dbus-sdr::join-handler
	# stage 1c -- choose random address
	pick-pnode-addr
	# stage 1d -- declare victory
	if {$owner} {
	    set joined 1
	    return $addr
	}
	# stage 1e -- begin the join process
	# set timeout handler for join request
	set timeout [after 200 ::dbus-sdr::join-timeout]
	# assign serial number for join request
	set jserial [incr serial]
	# send join request
	send-signal Join [list * $addr $jserial {join request}]
	# wait for join to complete
	vwait joined
	# return our address
	return $addr
    } elseif { ! [info exists joined]} {
	# stage 2 -- not joined
	# wait for the join to complete
	vwait joined
	return $addr
    } else {
	# stage 3 -- joined
	return $addr
    }
}

#
# two sided handler
# in already joined node, respond to requests to join from new nodes
# in new node, handle responses from already joined nodes
proc ::dbus-sdr::join-handler {dict args} {
    variable joined
    variable addr
    variable serial
    variable pnodes
    variable replies
    variable jserial

    lassign [lindex $args 0] to from mserial message
    if {[info exists joined]} {
	# in already joined node
	switch -glob $message {
	    {join request} {
		if {[find-pnode-addr $from]} {
		    send-signal Join [list $from $addr [incr serial] "join no $mserial"]
		} else {
		    send-signal Join [list $from $addr [incr serial] "join yes $mserial"]
		}
	    }
	    {join yes *} -
	    {join no *} {
		# replies not of interest to us
	    }
	    {join confirm} {
		lappend pnodes $from
	    }
	    default { error "join-handler: unrecognized message 1: $args" }
	}
    } else {
	# in new node
	switch -glob $message {
	    {join request} {
		# no opinion until we join
	    }
	    {join yes *} -
	    {join no *} {
	    	if {$to eq $addr && [lindex $message 2] == $jserial} {
		    lappend replies [list $from $message]
		}
	    }
	    {join confirm} {
		# not our problem
	    }
	    default { error "join-handler: unrecognized message 2: $args" }
	}
    }
    #log 5 "join-handler $args"
}

proc ::dbus-sdr::join-timeout {} {
    variable replies
    variable joined
    variable addr
    variable serial
    variable jserial
    log 5 [join $replies \n]
    lassign {0 0} no yes
    foreach r $replies {
	lassign $r from message
	add-pnode-addr $from
	switch -glob $message {
	    *no { incr no }
	    *yes { incr yes }
	    default {
	    }
	}
    }
    if {$no == 0} {
	set joined true
	send-signal Join [list * $addr [incr serial] {join confirm}]
    } else {
	pick-pnode-addr
	set timeout [after 200 ::dbus-sdr::join-timeout]
	set jserial [incr serial]
	send-signal Join [list * $addr $jserial {join request}]
    }
}

proc ::dbus-sdr::signal-handler {dict args} {
    variable signals
    set member [dict get $dict member]
    log 5 "handle: $member $args"
    foreach handler $signals($member) {
	if {[catch {{*}$handler $dict {*}$args} error]} {
	    set index [lsearch $signals($member) $handler]
	    if {$index >= 0} {
		set signals($member) [lreplace $signals($member) $index $index]
	    }
	    log 1 "removing dbus-sdr::signal $handler from $member signal handling: $error"
	}
    }
}

proc ::dbus-sdr::listen-for {member script} {
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

proc ::dbus-sdr::call-method {interface method {sig {}} args} {
    log 5 "call-method: $member $args"
    return [dbus call session -dest org.sdrkit.service -signature $sig /org/sdrkit/Service org.sdrkit.$interface $method {*}$args]
}

proc ::dbus-sdr::send-signal {member args} {
    log 5 "send-signal: $member $args"
    return [dbus signal session /org/sdrkit/Service org.sdrkit.Service $member {*}$args]
}

