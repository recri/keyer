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
package require usb 1.0
package require alsa::device
package require alsa::pcm
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
	foreach item {usb alsa jack jack-details jack-connections} {
	    .tab add [$item-panel .tab.$item -container $self] -text $item
	    $item-update .tab.$item
	}
    }

    destructor { }

    method configure {args} {
	foreach {opt val} $args {
	    set options($opt) $val
	}
    }

    #
    # enumerate usb devices
    #

    typevariable usbtypes -array {
	types {hub camera tablet audio midi dial libusb}
	8087:0024 hub
	1d6b:0002 hub
	058f:6254 hub
	04f2:b217 camera
	056a:00e6 tablet
	040d:3400 audio
	077d:07af audio
	16c0:0485 midi
	16c0:05dc libusb
	077d:0410 dial
	0b33:0020 dial
    } 

    proc usb-refresh {} {
	set devs {}
	usb::init
	foreach d [usb::get_device_list] {
	    set desc [usb::get_device_descriptor $d]
	    lappend desc bus_number [usb::get_bus_number $d] device_address [usb::get_device_address $d]
	    if {[catch {
		set h [usb::open $d]
		lappend desc opened true
		usb::close $h
	    } error]} {
		# cannot open, probably lack permission and need udev.d rule for device
		lappend desc opened false
	    }
	    lappend devs $desc
	}
	usb::exit
	return $devs
    }
    
    # usb report window
    proc usb-panel {w args} {
	ttk::frame $w
	return $w
    }
    
    proc usb-update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach c [usb-refresh] {
	    array set dev $c
	    incr i
	    set id [format {%04x:%04x} $dev(idVendor) $dev(idProduct)]
	    if {[info exists usbtypes($id)]} {
		set type $usbtypes($id)
	    } else {
		set type {unknown}
	    }
	    set l0 [ttk::label $w.t$i -text $type]
	    set l1 [ttk::label $w.x$i -text [format {%d-%d} $dev(bus_number) $dev(device_address)]]
	    set l2 [ttk::label $w.y$i -text $id]
	    grid $l0 $l1 $l2 -sticky e
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

    proc alsa-refresh {} {
	set devs {}
	foreach {c sname lname} [alsa::device cards] {
	    set dev [list card $c name $sname longname $lname devs [alsa::device devices $c]]
	    lappend devs $dev
	}
	#foreach x [alsa::pcm list] { lappend devs [list pcm $x] }
	return $devs
    }
    
    proc alsa-panel {w args} {
	ttk::frame $w
	return $w
    }
    
    proc alsa-update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach c [alsa-refresh] {
	    array set dev $c
	    incr i
	    set l1 [ttk::label $w.x$i -text $dev(card)]
	    set l2 [ttk::label $w.y$i -text $dev(name)]
	    grid $l1 $l2 -sticky e
	}
    }
    
    proc alsa-device-list {} {
	set devices {}
	foreach x [alsa-refresh] {
	    array set y $x
	    lappend devices $y(name)
	}
	return $devices
    }

    proc alsa-device-primary-default {} {
	foreach device [alsa-device-list] {
	    if {[info exists audiodevices1($device)] && $audiodevices1($device) ne {-}} {
		return $device
	    }
	}
	return [lindex [alsa-device-list] 1]
    }
    proc alsa-device-secondary-default {} {
	foreach device [alsa-device-list] {
	    if {[info exists audiodevices2($device)]} {
		return $device
	    }
	}
	return [lindex [alsa-device-list] 0]
    }

    proc alsa-rate-list {} {
	return {16000 24000 48000 96000 192000}
    }

    proc alsa-rate-default {device} {
	if {[info exists audiodevices1($device)]} {
	    return $audiodevices1($device)
	}
	return 96000
    }

    proc alsa-device-for-name {name} {
	foreach x [alsa-refresh] {
	    array set y $x
	    if {$y(name) eq $name} {
		#puts "matched: $x"
		return $y(card)
	    }
	}
	error "no match for audio device name {$name}"
    }

    #
    # select primary and secondary audio interfaces
    # primary sets the jack clock, listens to and talks to radio
    # secondary adapts to primary clock, listens to microphone and talks to speakers or headphones
    # select primary and secondary sample rate, preferably the same
    #
    # provide feedback on server status, overruns, connections, etc 
    #
    proc jack-control {args} {
	catch [list exec jack_control {*}$args 2>&1] result
	return $result
    }
    proc jack-status {} {
	return [lindex [split [jack-control status] \n] 1]
    }

    method jack-started {} {
	return [expr {[jack-status] ne {stopped}}]
    }

    proc jack-start {w} {
	set cmds [list \
		      [list jack-control ds alsa] \
		      [list jack-control dps device [jack-primary-device $w]] \
		      [list jack-control dps rate [jack-primary-rate $w]] \
		      [list jack-control start] \
		      [list jack-control ips audioadapter device [jack-secondary-device $w]] \
		      [list jack-control ips audioadapter rate [jack-secondary-rate $w]] \
		      [list jack-control iload audioadapter] \
		     ]
	foreach cmd $cmds {
	    puts "$cmd -> [{*}$cmd]"
	}
    }

    proc jack-stop {w} {
	jack-control iunload audioadapter
	jack-control stop
    }

    proc jack-primary-device {w} { return [alsa-device-for-name [option-menu-selected $w.pam]] }
    proc jack-primary-rate {w} { return [option-menu-selected $w.prm] }
    proc jack-secondary-device {w} { return [alsa-device-for-name [option-menu-selected $w.sam]] }
    proc jack-secondary-rate {w} { return [option-menu-selected $w.srm] }

    proc jack-panel {w args} {
	upvar #0 $w data
	ttk::frame $w
	set primary [alsa-device-primary-default]
	grid [ttk::label $w.pal -text {primary}] [option-menu $w.pam [alsa-device-list] $primary] \
	    [ttk::label $w.prl -text {@}] [option-menu $w.prm [alsa-rate-list] [alsa-rate-default $primary]] -sticky ew
	grid [ttk::label $w.sal -text {secondary}] [option-menu $w.sam [alsa-device-list] [alsa-device-secondary-default]] \
	    [ttk::label $w.srl -text {@}] [option-menu $w.srm [alsa-rate-list] [alsa-rate-default $primary]] -sticky ew
	grid [ttk::frame $w.s] -columnspan 4
	pack [ttk::label $w.s.status -textvar ${w}(status)] -side left
	pack [ttk::button $w.s.start -text start -command [myproc jack-start $w]] -side left
	pack [ttk::button $w.s.stop -text stop -command [myproc jack-stop $w]] -side left
	jack-update-status $w
	return $w
    }

    proc jack-update-status {w} {
	upvar #0 $w data
	set data(status) [jack-status]
	if {$data(status) eq {stopped}} {
	    $w.s.start configure -state normal
	    $w.s.stop configure -state disabled
	} else {
	    $w.s.start configure -state disabled
	    $w.s.stop configure -state normal
	}
	after 100 [myproc jack-update-status $w]
    }

    proc jack-update {w} {
    }

    #
    # this should show the additional options necessary
    # to start the jack server as we need it to run
    #
    proc jack-details-panel {w args} {
	ttk::frame $w
	return $w
    }
    proc jack-details-update {w} {
    }

    #
    # this displays the jack clients active
    # and their connections
    #
    proc jack-connections-panel {w args} {
	startup-jconn $w {*}$args
	return $w
    }
    proc jack-connections-update {w} {
    }

}

