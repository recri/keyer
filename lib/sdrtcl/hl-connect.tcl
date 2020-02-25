# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA
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
package provide sdrtcl::hl-connect 0.0.1

package require snit
package require udp
package require sdrtcl::hl-udp-jack

namespace eval ::sdrtcl {}

#
# hmm, I'm thinking that the option value handler can be separated
# from the sample handlers.  The option value manager only deals
# with buffers at one step from the network, stripping out the rx
# option values and inserting the tx option values
#

# hl-connect - hermes-lite udp connection manager
# establishes connection
# receives rx-iq and bandscope packets from hl2
# dispatches packets to appropriate handlers
# receives tx-iq packets from appropriate handler
# sends tx-iq packets to hl2
# delegates control information to the handlers
#
snit::type sdrtcl::hl-connect {
    component iqhandler;	# the rx and tx iq stream(s) handler
    component bshandler;	# the bandscope stream handler
    
    # local procedures
    # map a list of byte values as hex
    proc as-hex {bytes} {
	set hex {}
	foreach b $bytes { lappend hex [format %02x [expr {$b&0xff}]] }
	return $hex
    }
    # map the speed into the 2 bit value sent to the hardware
    proc map-speed {val} {
	switch $val {
	    48000 { return 0 }
	    96000 { return 1 }
	    192000 { return 2 }
	    384000 { return 3 }
	    default { error "unexpected speed: $speed" }
	}
    }
    
    # local data
    # keep most of it all in one array
    variable d -array {
	socket {}
	stopped 1
    }

    #
    # options
    #

    # these are discovered during connection to the hl
    option -peer -default {} -readonly true
    option -code-version -default -1 -type snit::integer -readonly true
    option -board-id -default -1 -type snit::integer -readonly true
    option -mac-addr -default {} -readonly true
    option -mcp4662 -default {} -readonly true
    option -fixed-ip -default {} -readonly true
    option -fixed-mac -default {} -readonly true
    option -n-hw-rx -default -1 -readonly true
    option -wb-fmt -default -1 -readonly true
    option -build-id -default -1 -readonly true
    option -gateware-minor -default -1 -readonly true

    # this one enters into the start command
    option -bandscope -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {hl conf}

    # these are handled separate from the other hl-udp-jack options
    # because they require restarting the component when they change
    option -speed -configuremethod set-speed
    option -n-rx -configuremethod set-n-rx

    # the rest of the methods are delegated to the iqhandler component
    delegate option * to iqhandler
    
    variable optiondocs -array {
	-peer {The IP address and port of the connected board.}
	-mac-addr {The MAC address of the connected board.}
	-code-version {The Hermes code version reported by the connected board.}
	-board-id {The board identifier reported by the connected board}

	-bandscope {Enable the bandscope samples.}
	
	-speed {Choose speed of IQ samples to be 48000, 96000, 192000, or 384000 samples per second.}
	-n-rx {Number of receivers to implement, from 1 to 8 permitted, current HermesLite can do 1 to 4.}
    }

    ##
    ## hl - hermes lite / metis start stop socket handlers
    ##
    method {hl begin} {} {
	# puts "hl start"
	set d(stopped) 1
	set d(socket) [udp_open]
	fconfigure $d(socket) -translation binary -blocking 0 -buffering none -remote $options(-peer)
	fileevent $d(socket) readable [mymethod rx readable $d(socket)]
	$self rx reset;		# leftovers
	$self hl restart
    }

    method {hl restart} {} {
	# puts "hl restart"
	$self hl stop
	$self tx reset
	$self rx reset
	$self hl start
    }

    method {hl stop} {} {
	puts -nonewline $d(socket) [binary format Ia60 0xeffe0400 {}]
	set d(stopped) 1
    }

    method {hl start} {} {
	set d(stopped) 0
	puts -nonewline $d(socket) [binary format Ia60 [expr {0xeffe0401 | ($options(-bandscope)<<1)}] {}]
    }

    method {hl conf} {opt val} {
	set options($opt) $val
	set d(restart-requested) 1
    }

    ##
    ## tx - transmitter
    ##

    method {tx constructor} {args} {
    }

    method {tx reset} {} {
	# reset sequences
    }
    
    method {tx send} {b1 b2 {force 0}} {
	incr d(tx-calls)
	set n [expr {[string length $b1]+[string length $b2]}]
	incr d(tx-bytes) $n
	set ns [expr {int($n/8)}]; # L,R,I,Q * 2 bytes each
	incr d(tx-samples) $ns
	if {$d(stopped) && ! $force} return
	if {$d(restart-requested)} {
	    set d(restart-requested) 0
	    $self hl stop
	    after 1 [mymethod hl restart]
	    #$self hl restart
	    return
	}
	set c1 [$self tx control]
	set c2 [$self tx control]
	set pkt [binary format IIa3a5a504a3a5a504 \
				     0xeffe0102 $d(tx-sequence) \
				     "\x7f\x7f\x7f" $c1 $b1 \
				     "\x7f\x7f\x7f" $c2 $b2]
	puts -nonewline $d(socket) $pkt
	incr d(tx-sequence)
    }

    ##
    ## rx - receiver
    ##
    method {rx constructor} {} {
	# deal with missing -rx and -bs handlers
	if {$options(-rx) eq {}} { set options(-rx) [mymethod dummy rx] }
	if {$options(-tx) eq {}} { set options(-tx) [mymethod dummy tx] }
	if {$options(-bs) eq {}} { set options(-bs) [mymethod dummy bs] }
    }

    method {rx reset} {} {
	set d(iq-sequence) 0
	set d(bs-sequence) 0
	set d(bs-buff) {}
	foreach i {1 2} {
	    while {[read $d(socket)] ne {}} {}
	    after 1
	}
	while {[read $d(socket)] ne {}} {}
    }

    method {rx readable} {socket} {
	while {1} {
	    set data [read $socket]
	    set n [string length $data]
	    if {$d(stopped)} {
		puts "rx readable: drop packet size $n because stopped"
		return
	    }
	    if {$n != 1032} {
		binary scan $data c* bytes
		puts "rx readable: unknown packet size $n: [as-hex $bytes]"
		return
	    }
	    # scan the preamble, leave the usb packets in place
	    # was: binary scan $data IIa512a512 syncep seq f1 f2
	    # f1 is $data offset 8, f2 is $data offset 520
	    if {[binary scan $data II syncep seq] != 2} {
		puts "rx readable: metis scan failed"
		return
	    }
	    if {($syncep&0xFFFFFF00) != 0xeffe0100} {
		puts "rx readable: metis sync bytes wrong: [format 0x08x $syncep]"
		return
	    }
	    set ep [expr {$syncep&0xFF}]
	    switch $ep {
		6 { # iq data
		    set in [{*}$options(-rx) $data]
		    if {$in != {}} {
			$self tx send $in
		    }
		}
		4 { # bandscope samples
		    {*}$options(-bs) $data		    
		}
		default {
		    puts "rx readable: unknown endpoint $ep"
		}
	    }
	}
    }

    ##
    ## dummy rx IQ and bandscope handlers
    ## it will just have to do,
    ## until the real thing comes along
    ##
    method {dummy rx} {data} {
	incr d(dummy-rx-calls)
	incr d(dummy-rx-bytes)
	set n 1008
	incr d(dummy-rx-bytes) $n
	set ns [expr {int($n/($::options(-n-rx)*6+2))}]
	incr d(dummy-rx-samples) $ns
	incr d(dummy-tx-samples) $ns
	# the number of rx samples at -n-rx and -speed
	# equivalent to 126 tx samples at 48000 ksps
	set txinc [expr {-126*$::options(-speed)/48000}]
	if {$d(dummy-tx-samples) + $txinc >= 0} {
	    incr d(dummy-tx-samples) $txinc
	    incr d(dummy-tx-returns)
	    return { {} {} }
	}
    }
    method {dummy bs} {args} {
	incr d(dummy-bs-calls)
	set n 0
	foreach b $args { incr n [string length $b] }
	incr d(dummy-bs-bytes) $n
	incr d(dummy-bs-samples) [expr {$n/2}]
    }
    ##
    ## statistics on buffers sent and received
    ##
    method {stats reset} {} {
	array set d {
	    rx-calls 0 rx-bytes 0 rx-samples 0
	    tx-calls 0 tx-bytes 0 tx-samples 0
	    bs-calls 0 bs-bytes 0 bs-samples 0
	}
    }
    method {stats rx} {} { return [concat {*}[lmap x {calls bytes samples} {list rx-$x $d(rx-$x)}]] }
    method {stats tx} {} { return [concat {*}[lmap x {calls bytes samples} {list tx-$x $d(tx-$x)}]] }
    method {stats bs} {} { return [concat {*}[lmap x {calls bytes samples} {list bs-$x $d(bs-$x)}]] }
    #
    # main constructor
    #
    constructor {args} {
	$self configurelist $args
	$self tx constructor
	$self rx constructor
	$self stats reset
    }
}
    
    
