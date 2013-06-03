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
    variable cards -array {}

    # audio device names and preferred sample rate
    # in preference order
    typevariable audiodevices1 {
	{VIA USB Dongle} 96000
	{iMic USB audio system} 48000
	{HDA Intel PCH} 96000
	{Teensy MIDI} -
    }
    typevariable audiodevices2 {
	{HDA Intel PCH} 96000
    }

    method refresh {} {
	array unset cards
	foreach {card sname lname} [alsa::device cards] {
	    # puts "$c $sname $lname"
	    lappend cards($card) card $card name $sname longname $lname devs [alsa::device devices $card]
	    set primary [lsearch $audiodevices1 $sname]
	    set secondary [lsearch $audiodevices2 $sname]
	    if {$primary >= 0} {
		lappend cards($card) primary [expr {[llength $audiodevices1]-$primary}] rate [lindex $audiodevices1 [incr primary]]
	    } else {
		lappend cards($card) primary $primary rate -
	    }
	    if {$secondary >= 0} {
		lappend cards($card) secondary [expr {[llength $audiodevices2]-$secondary}]
	    } else {
		lappend cards($card) secondary $secondary
	    }
	    #puts $cards($card)
	}
	return [array get cards]
    }
    
    method panel {w args} {
	ttk::frame $w
	$self update $w
	return $w
    }
    
    method card-list {} {
	$self refresh
	return [lsort [array names cards]]
    }

    method update {w} {
	foreach c [pack slaves $w] {
	    pack forget $c
	    $c destroy
	}
	set i 0
	foreach card [$self card-list] {
	    array set info $cards($card)
	    incr i
	    set l1 [ttk::label $w.x$i -text $info(card)]
	    set l2 [ttk::label $w.y$i -text $info(name)]
	    set l3 [ttk::label $w.z$i -text $info(primary)]
	    set l4 [ttk::label $w.a$i -text $info(secondary)]
	    set l5 [ttk::label $w.b$i -text $info(rate)]
	    grid $l1 $l2 $l3 $l4 $l5 -sticky e
 	}
    }
    
    method card-primary-default {} {
	set max -1
	foreach card [$self card-list] {
	    if { ! [info exists can]} { set can $card }
	    array set info $cards($card)
	    if {$info(primary) > $max} {
		set max $info(primary)
		set can $card
	    }
	}
	return $can
    }

    method card-secondary-default {} {
	set max -1
	foreach card [$self card-list] {
	    if { ! [info exists can]} { set can $card }
	    array set info $cards($card)
	    if {$info(secondary) >= $max} {
		set max $info(secondary)
		set can $card
	    }
	}
	return $can
    }

    method rate-list {} {
	return {8000 16000 24000 32000 48000 96000 192000}
    }

    method rate-default {card} {
	array set info $cards($card)
	if {$info(rate) ne {-}} { return $info(rate) }
	return 96000
    }

}

