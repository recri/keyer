# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA
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
#https://github.com/pd-l2ork/pd/blob/master/extensions/gui/ix/osc.tcl
#OSC tcl 2005 ix

# use same transport (udp or tcp) as $::env(NSM_URL)
# liblo has flaky tcp implementation, so udp is most likely
# /nsm/server/announce s:application_name s:capabilities s:executable_name i:api_version_major i:api_version_minor i:pid
# i:api_version_major == 1 i:api_version_minor == 0

package require udp

package provide osc 1.0

# i	int32
# f	float32
# s	OSC-string
# b	OSC-blob
# h	64 bit big-endian two's complement integer
# t	OSC-timetag
# d	64 bit ("double") IEEE 754 floating point number
# S	Alternate type represented as an OSC-string (for example, for systems that differentiate "symbols" from "strings")
# c	an ascii character, sent as 32 bits
# r	32 bit RGBA color
# m	4 byte MIDI message. Bytes from MSB to LSB are: port id, status byte, data1, data2
# T	True. No bytes are allocated in the argument data.
# F	False. No bytes are allocated in the argument data.
# N	Nil. No bytes are allocated in the argument data.
# I	Infinitum. No bytes are allocated in the argument data.
# [	Indicates the beginning of an array. The tags following are for data in the Array until a close brace tag is reached.
# ]	Indicates the end of an array.

namespace eval ::osc {}

proc ::osc::format {type data} {
    switch $type {
	i -
	c -
	m -
	r { return [binary format I $data] }
	f { return [binary format R $data] }
	s -
	S {
	    set n [string length $data]
	    set x [expr {(($n+1+3)&~3)-$n}]
	    return [binary format a${n}x${x} $data]
	}
	b {
	    set n [string length $data]
	    set x [expr {(($n+3)&~3)-$n}]
	    return [binary format Ia${n}x{$x} $n $data]
	}
	h -
	t { return [binary format W $data] }
	d { return [binary format Q $data] }
	T -
	F -
	N -
	I -
	\[ -
	\] { return {} }
    }
    error "unhanded type {$type} in osc::encode"
}
proc ::osc::scan {type datavar} {
    upvar $datavar data
    while 1 {
	switch $type {
	    i -
	    c -
	    m -
	    r {
		if {[binary scan $data Ia* val data] != 2} break
		return $val
	    }
	    f {
		if {[binary scan $data $a* val data] != 2} break
		return $val 
	    }
	    s -
	    S {
		set n [string first \0 $data]
		if {$n < 0} break
		set x [expr {(($n+1+3)&~3)-$n}]
		if {[binary scan $data a${n}x${x}a* val data] != 2} break
		return $val
	    }
	    b {
		if {[binary scan $data Ia* n data] != 2} break
		set x [expr {(($n+3)&~3)-$n}]
		if {[binary scan $data a${n}x${x}a* val data] != 2} break
		return $val
	    }
	    h -
	    t {
		if {[binary scan $data Wa* val data] != 2} break
		return $val
	    }
	    d {
		if {[binary scan $data Qa* val data] != 2} break
		return $val
	    }
	    T { return 1 }
	    F { return 0 }
	    N { return {} }
	    I { return [expr {1.0/0.0}] }
	}
    }
    error "failed to scan {$type} in {$data}"
}
proc ::osc::message {path types args} {
    set body {}
    foreach type [split $types {}] arg $args {
	append body [::osc::format $type $arg]
    }
    return [::osc::format s $path][::osc::format s ,$types]$body
}
proc ::osc::connect {host port} {
    set s [udp_open]
    fconfigure $s -remote [list $host $port] -buffering none -translation binary
    return $s
}
proc ::osc::disconnect {socket} {
    close $socket
}
proc ::osc::send {socket msg} {
    puts -nonewline $socket $msg
}
proc ::osc::listen {port} {
}

#
# Time tags are represented by a 64 bit fixed point number. The first
# 32 bits specify the number of seconds since midnight on January 1,
# 1900, and the last 32 bits specify fractional parts of a second to a
# precision of about 200 picoseconds. This is the representation used
# by Internet NTP timestamps.The time tag value consisting of 63 zero
# bits followed by a one in the least signifigant bit is a special
# case meaning "immediately." 
#
# this is sort of stupid.  tcl gives me microseconds since the epoch.
# jack gives me microseconds since its epoch.  the difference is
# pretty consistent, so all I need to convert jack time in
# microseconds to or from epoch time in microseconds is to add an
# offset.  Converting to the OSC format requires extracting the
# microseconds remainder in the second, scaling to fixed point and
# packing, just so I can unpack back to microseconds to figure out the
# jack frame.

#
# the roundtrip through these two conversions is off by a microsecond
#
set ::osc::million 1000000
set ::osc::epoch [expr {$::osc::million*[clock scan {1900-01-01 00:00:00 UTC} -format {%Y-%m-%d %H:%M:%S %Z}]}]

# convert the microseconds from epoch 1970-01-01
# to a osc timetag
proc ::osc::timetag {microseconds} {
    set ot [expr {$microseconds-$::osc::epoch}]
    set us [expr {$ot%$::osc::million}]
    set s [expr {$ot/$::osc::million}]
    return [expr {($s<<32)|(($us<<32)/$::osc::million)}]
}

# convert an osc timetag to microseconds from epoch 1970-01-01
proc ::osc::microseconds {tag} {
    set us [expr {($::osc::million*($tag&0xFFFFFFFF))>>32}]
    set s [expr {$tag>>32}]
    return [expr {$s*$::osc::million+$us+$::osc::epoch}]
}
