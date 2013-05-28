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
# the usb startup manager
#
package provide sdrkit::startup-usb 1.0.0

package require snit
package require usb 1.0

namespace eval sdrkit {}

snit::type sdrkit::startup-usb {

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
	16c0:0483 serial
	16c0:05dc libusb
	077d:0410 dial
	0b33:0020 dial
    } 

    method refresh {} {
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
}

