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

#
# we need the component wrapper
#
package require sdrkit::component

#
# create the namespace for the component wrappers
#
namespace eval sdrkitv {}

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

    method rename-panel {w name} {
	.tab tab $w -text $name
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

    method usb-refresh {} {
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
    method usb-panel {w args} {
	ttk::frame $w
	return $w
    }
    
    method usb-update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach c [$self usb-refresh] {
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

    method alsa-refresh {} {
	set devs {}
	foreach {c sname lname} [alsa::device cards] {
	    set dev [list card $c name $sname longname $lname devs [alsa::device devices $c]]
	    lappend devs $dev
	}
	#foreach x [alsa::pcm list] { lappend devs [list pcm $x] }
	return $devs
    }
    
    method alsa-panel {w args} {
	ttk::frame $w
	return $w
    }
    
    method alsa-update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach c [$self alsa-refresh] {
	    array set dev $c
	    incr i
	    set l1 [ttk::label $w.x$i -text $dev(card)]
	    set l2 [ttk::label $w.y$i -text $dev(name)]
	    grid $l1 $l2 -sticky e
	}
    }
    
    method alsa-device-list {} {
	set devices {}
	foreach x [$self alsa-refresh] {
	    array set y $x
	    lappend devices $y(name)
	}
	return $devices
    }

    method alsa-device-primary-default {} {
	foreach device [$self alsa-device-list] {
	    if {[info exists audiodevices1($device)] && $audiodevices1($device) ne {-}} {
		return $device
	    }
	}
	return [lindex [$self alsa-device-list] 1]
    }
    method  alsa-device-secondary-default {} {
	foreach device [$self alsa-device-list] {
	    if {[info exists audiodevices2($device)]} {
		return $device
	    }
	}
	return [lindex [$self alsa-device-list] 0]
    }

    method alsa-rate-list {} {
	return {16000 24000 48000 96000 192000}
    }

    method alsa-rate-default {device} {
	if {[info exists audiodevices1($device)]} {
	    return $audiodevices1($device)
	}
	return 96000
    }

    method alsa-device-for-name {name} {
	foreach x [$self alsa-refresh] {
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
    method jack-control {args} {
	catch [list exec jack_control {*}$args 2>&1] result
	return $result
    }
    method jack-status {} {
	return [lindex [split [$self jack-control status] \n] 1]
    }

    method jack-started {} {
	return [expr {[$self jack-status] ne {stopped}}]
    }

    method jack-start {w} {
	set cmds [list \
		      [list jack-control ds alsa] \
		      [list jack-control dps device [$self jack-primary-device $w]] \
		      [list jack-control dps rate [$self jack-primary-rate $w]] \
		      [list jack-control start] \
		      [list jack-control ips audioadapter device [$self jack-secondary-device $w]] \
		      [list jack-control ips audioadapter rate [$self jack-secondary-rate $w]] \
		      [list jack-control iload audioadapter] \
		     ]
	foreach cmd $cmds {
	    puts "$cmd -> [$self {*}$cmd]"
	}
	$self app-launch [$self sdrkit-app $w]
    }

    method jack-stop {w} {
	$self jack-control iunload audioadapter
	$self jack-control stop
    }

    method jack-primary-device {w} { return [$self alsa-device-for-name [option-menu-selected $w.pam]] }
    method jack-primary-rate {w} { return [option-menu-selected $w.prm] }
    method jack-secondary-device {w} { return [$self alsa-device-for-name [option-menu-selected $w.sam]] }
    method jack-secondary-rate {w} { return [option-menu-selected $w.srm] }

    method sdrkit-app-list {} { return {none keyer rx rxtx loopback} }
    method sdrkit-app-default {} { return {keyer} }
    method sdrkit-app {w} { return [option-menu-selected $w.a.app] }

    method jack-panel {w args} {
	upvar #0 $w data
	ttk::frame $w
	set primary [$self alsa-device-primary-default]
	grid [ttk::label $w.pal -text {primary}] [option-menu $w.pam [$self alsa-device-list] $primary] \
	    [ttk::label $w.prl -text {@}] [option-menu $w.prm [$self alsa-rate-list] [$self alsa-rate-default $primary]] -sticky ew
	grid [ttk::label $w.sal -text {secondary}] [option-menu $w.sam [$self alsa-device-list] [$self alsa-device-secondary-default]] \
	    [ttk::label $w.srl -text {@}] [option-menu $w.srm [$self alsa-rate-list] [$self alsa-rate-default $primary]] -sticky ew
	grid [ttk::frame $w.s] -columnspan 4
	pack [ttk::label $w.s.status -textvar ${w}(status)] -side left
	pack [ttk::button $w.s.start -text start -command [mymethod jack-start $w]] -side left
	pack [ttk::button $w.s.stop -text stop -command [mymethod jack-stop $w]] -side left
	$self jack-update-status $w
	grid [ttk::frame $w.a] -columnspan 4
	pack [ttk::label $w.a.lab -text application] -side left
	pack [option-menu $w.a.app [$self sdrkit-app-list] [$self sdrkit-app-default]]
	return $w
    }

    method jack-update-status {w} {
	upvar #0 $w data
	set data(status) [$self jack-status]
	if {$data(status) eq {stopped}} {
	    $w.s.start configure -state normal
	    $w.s.stop configure -state disabled
	} else {
	    $w.s.start configure -state disabled
	    $w.s.stop configure -state normal
	}
	after 100 [mymethod jack-update-status $w]
    }

    method jack-update {w} {
    }

    #
    # this should show the additional options necessary
    # to start the jack server as we need it to run
    #
    method jack-details-panel {w args} {
	ttk::frame $w
	return $w
    }
    method jack-details-update {w} {
    }

    #
    # this displays the jack clients active
    # and their connections
    #
    method jack-connections-panel {w args} {
	startup-jconn $w {*}$args
	return $w
    }
    method jack-connections-update {w} {
    }

    method app-panel {w args} {
	set data(app-window) $w
	set data(app-args) {}
	foreach {name value} $args {
	    if {$name in {-container}} {
		continue
	    } else {
		lappend data(app-args) $name $value
	    }
	}
	ttk::frame $w
	return $w
    }

    method app-update {w} {
    }
    method app-launch {name} {
	$self rename-panel $data(app-window) $name
	switch $name {
	    none { }
	    keyer {
		package require sdrkit::$name
		sdrkit::component ::sdrkitv::$name -window $data(app-window) -name $name -subsidiary sdrkit::$name -subsidiary-opts $data(app-args) -enable true -activate true \
		    -source system:midi_capture_1 -sink {system:playback_1 system:playback_2}
	    }
	    rx {
		# -rx-source "$RXSOURCE" -rx-sink "$RXSINK" "$@"
		package require sdrkit::$name
		sdrkit::component ::sdrkitv::$name -window $data(app-window) -name $name -subsidiary sdrkit::$name -subsidiary-opts $data(app-args) -enable true -activate true \
		    -rx-source {system:capture_1 system:capture_2} -rx-sink {audio_adapter:playback_1 audio_adapter:playback_2}
	    }
	    rxtx {
		package require sdrkit::$name
		sdrkit::component ::sdrkitv::$name -window $data(app-window) -name $name -subsidiary sdrkit::$name -subsidiary-opts $data(app-args) -enable true -activate true \
		    -rx-source {system:capture_1 system:capture_2} -rx-sink {audio_adapter:playback_1 audio_adapter:playback_2} \
		    -tx-source {system:playback_1 system:playback_2} -rx-sink {audio_adapter:capture_1 audio_adapter:capture_2} \
	    }
	    loopback {
		# -rx-source "$RXSOURCE" -rx-sink "$RXSINK" "$@"
	    }
	    default {
		error "unknown app name $name"
	    }
	}
    }

}

