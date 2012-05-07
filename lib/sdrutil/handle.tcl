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
# a handle started out being just the opened usb device handle
# returned by dg8saq::find_handles, but that routine actually
# returned a bunch of other stuff in a list.  So handle makes
# that bunch of stuff into the core of the other information
# we need to program the device on the other side of the
# handle.
#
# most immediately, it provides a way to specify the Si570
# parameters that are usually the same, but could vary, so
# that we can stop using the default constants wired into
# the dg8saq module.
#
# but we also store all the other information which the device
# can tell us, recording whatever changes we make along the way.
#
# and maybe we make it the "handle" by which all hardware
# resources are kept sorted out.  arduinos can have handles,
# audio devices can have handles, pcm devices can have handles
# and so on.
#
# so how do we manage that?
#

##
## not sure how to make this work correctly.  if we use libusb to open a device handle
## and then the device disconnects and reconnects, how similar will the next libusb
## poll of devices be?
##
## the bus and address will change when the device reconnects.
## the vendor product serial triple will be the same for all devices of a group, unless
## they've been given distinct serial ids.
##
## if I hold them open, the handle and device may change on a subsequent 

package provide handle 1.0
package require dg8saq
#package require arduino

namespace eval handle {
    set usb_init_called 0
    set next_handle 0
    array set handles {}
}

proc handle::new {class subclass device handle bus address vendor_id product_id vendor product serial} {
    set h $handle::next_handle
    incr handle::next_handle
    set handle::handles($h) [dict create type handle \
				 class $class subclass $subclass \
				 device $device handle $handle \
				 bus $bus address $address \
				 vendor_id $vendor_id product_id $product_id \
				 vendor $vendor product $product serial $serial]
    foreach {name value} [namespace eval ::${subclass} { default_values }] {
	dict set handle::handles($h) $name $value
    }
    return $h
}

proc handle::match_device {class device hname} {
    foreach h [array names handle::handles] {
	if {$class eq [class $h] && $device == [device $h]} {
	    uplevel [list set $hname $h]
	    return 1
	}
    }
    return 0
}

proc handle::close {handle} {
}

proc handle::find_handles {class} {
    switch $class {
	usb {
	    if { ! $handle::usb_init_called } {
		set handle::usb_init_called 1
		usb::init
	    }
	    set found {}
	    foreach device [usb::get_device_list] {
		if {[match_device usb $device h]} {
		    # puts "matched usb device $device to $h"
		    usb::unref_device $device
		    lappend found $h
		    continue
		}
		array set desc [usb::get_device_descriptor $device]
		# puts [array get desc]
		if {[dg8saq::match_vendor_product $desc(idVendor) $desc(idProduct)]} {
		    if {[catch {usb::open $device} handle]} {
			error "failed to open dg8saq device [format %04x:%04x $desc(idVendor) $desc(idProduct)]"
		    }
		    lappend found [::handle::new usb dg8saq $device $handle \
				       [usb::get_bus_number $device]  [usb::get_device_address $device] \
				       $desc(idVendor) $desc(idProduct) \
				       [usb::convert_string [usb::get_string_descriptor $handle $desc(iManufacturer) 0]] \
				       [usb::convert_string [usb::get_string_descriptor $handle $desc(iProduct) 0]] \
				       [usb::convert_string [usb::get_string_descriptor $handle $desc(iSerialNumber) 0]] \
				      ]
		} else {
		    usb::unref_device $device
		}
	    }
	    # puts "found: $found"
	    foreach h [array names handle::handles] {
		if {[class $h] eq {usb} && [lsearch -exact $found $h] < 0} {
		    # this one is a goner
		    # puts "remove $h from handle list"
		    catch {usb::close [handle $h]}
		    catch {usb::unref [device $h]}
		    unset handle::handles($h)
		}
	    }
	    return $found
	}
	default {
	    error "unknown handle class $class"
	}
    }
}
# everything at once to refresh my memory
proc handle::getdict {h} { return $handle::handles($h) }
# the parts we inserted
proc handle::type {h} { return [dict get $handle::handles($h) type] }
proc handle::class {h} { return [dict get $handle::handles($h) class] }
proc handle::subclass {h} { return [dict get $handle::handles($h) subclass] }
# the parts we got from libusb, which cannot be changed by us
# but might change if the device reattaches to usb for some reason
proc handle::device {h} { return [dict get $handle::handles($h) device] }
proc handle::handle {h} { return [dict get $handle::handles($h) handle] }
proc handle::bus {h} { return [dict get $handle::handles($h) bus] }
proc handle::address {h} { return [dict get $handle::handles($h) address] }
# the parts that libusb got from the descriptors, which cannot be changed
proc handle::vendor_id {h} { return [dict get $handle::handles($h) vendor_id] }
proc handle::product_id {h} { return [dict get $handle::handles($h) product_id] }
proc handle::vendor {h} { return [dict get $handle::handles($h) vendor] }
proc handle::product {h} { return [dict get $handle::handles($h) product] }
# this came from the descriptor, but can be changed
proc handle::serial {h} { return [dict get $handle::handles($h) serial] }
proc handle::set_serial {h serial} { dict set handle::handles($h) serial $serial }
# a part which comes from the device and cannot be changed
proc handle::version {h} {
    if { ! [dict exists $handle::handles($h) version]} {
	dict set handle::handles($h) version [dg8saq::get_read_version $h]
    }
    return [dict get $handle::handles($h) version]
}
proc handle::set_version {h version} { dict set $handle::handles($h) version $version }
# the parts that the si570 defaults supplied, but can be changed
# in fact, can be read from the device
proc handle::si570_addr {h} { return [dict get $handle::handles($h) si570_addr] }
proc handle::set_si570_addr {h addr} { dict set handle::handles($h) si570_addr $addr }
proc handle::si570_xtal {h} { return [dict get $handle::handles($h) si570_xtal] }
proc handle::set_si570_xtal {h xtal} { dict set handle::handles($h) si570_xtal $xtal }
# the part that the si570 defaults supplied, but can be changed
# and can be computed from the values read from the device
# but must be supplied by the user if it's not right
proc handle::si570_startup {h} { return [dict get $handle::handles($h) si570_startup] }
proc handle::set_si570_startup {h startup} { dict set handle::handles($h) si570_startup $startup }
# the default si570 multiplier, usually 4 due to division down to get I/Q in Rx and RxTx
proc handle::multiplier {h} { return [dict get $handle::handles($h) multiplier] }
proc handle::set_multiplier {h multiplier} { dict set handle::handles($h) multiplier $multiplier }
# parts that the user supplies
proc handle::nickname {h} {
    if { ! [dict exists $handle::handles($h) nickname]} {
	set_nickname $h [guess_nickname $h]
    }
    return [dict get $handle::handles($h) nickname]
}
proc handle::set_nickname {h name} { dict set handle::handles($h) nickname $name }
proc handle::guess_nickname {h} {
    return [[subclass $h]::guess_nickname $h]
}
