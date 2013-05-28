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
# the alsa startup manager
#
package provide sdrkit::startup-alsa 1.0.0

package require snit
package require alsa::device
package require alsa::pcm

namespace eval sdrkit {}

snit::type sdrkit::startup-alsa {

    constructor {args} {
	$self configure {*}$args
    }

    destructor { }

    method configure {args} {
	foreach {opt val} $args {
	    set options($opt) $val
	}
    }

    #
    # enumerate alsa devices
    #

    # audio device names and sample rate
    typevariable  audiodevices1 -array {
	{VIA USB Dongle} 96000
	{iMic USB audio system} 48000
	{Teensy MIDI} -
	{HDA Intel PCH} -
    }
    typevariable audiodevices2 -array {
	{HDA Intel PCH} -
    }

    method refresh {} {
	set devs {}
	foreach {c sname lname} [alsa::device cards] {
	    set dev [list card $c name $sname longname $lname devs [alsa::device devices $c]]
	    lappend devs $dev
	}
	#foreach x [alsa::pcm list] { lappend devs [list pcm $x] }
	return $devs
    }
    
    method panel {w args} {
	ttk::frame $w
	$self update $w
	return $w
    }
    
    method update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach c [$self refresh] {
	    array set dev $c
	    incr i
	    set l1 [ttk::label $w.x$i -text $dev(card)]
	    set l2 [ttk::label $w.y$i -text $dev(name)]
	    grid $l1 $l2 -sticky e
	}
    }
    
    method device-list {} {
	set devices {}
	foreach x [$self refresh] {
	    array set y $x
	    lappend devices $y(name)
	}
	return $devices
    }

    method device-primary-default {} {
	foreach device [$self device-list] {
	    if {[info exists audiodevices1($device)] && $audiodevices1($device) ne {-}} {
		return $device
	    }
	}
	return [lindex [$self device-list] 1]
    }
    method  device-secondary-default {} {
	foreach device [$self device-list] {
	    if {[info exists audiodevices2($device)]} {
		return $device
	    }
	}
	return [lindex [$self device-list] 0]
    }

    method rate-list {} {
	return {16000 24000 48000 96000 192000}
    }

    method rate-default {device} {
	if {[info exists audiodevices1($device)]} {
	    return $audiodevices1($device)
	}
	return 96000
    }

    method device-for-name {name} {
	foreach x [$self refresh] {
	    array set y $x
	    if {$y(name) eq $name} {
		#puts "matched: $x"
		return $y(card)
	    }
	}
	error "no match for audio device name {$name}"
    }

}

