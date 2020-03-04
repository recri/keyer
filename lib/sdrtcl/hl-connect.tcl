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
package require sdrtcl::hl-discover
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
    proc as-hex {data} {
	set n [string length $data]
	binary scan $data c* bytes
	set hex {}
	foreach b $bytes { lappend hex [format %02x [expr {$b&0xff}]] }
	return "packet size $n: $hex"
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
	restart-requested 0
	rx-frames-per-call 126
    }

    #
    # options
    #

    # these are discovered during connection to the hl
    # most are probably being passed in directly
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
    option -bandscope -default 0 -type {snit::integer -min 0 -max 1} -configuremethod hl-conf

    # these are handled separate from the other hl-udp-jack options
    # because they require restarting the component when they change
    option -speed -default 48000 -configuremethod hl-conf
    option -n-rx -default 1 -configuremethod hl-conf

    # the rest of the options are delegated to the iqhandler component
    delegate option * to iqhandler
    delegate method activate to iqhandler

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
    method hl-begin {} {
	puts "hl-begin"
	set d(stopped) 1
	if {$options(-peer) != {}} {
	    $self hl-connect
	} else {
	    set d(socket) {}
	    $self rx-reset
	    $self hl-restart
	}
    }

    method hl-connect {} {
	set d(socket) [udp_open]
	regsub {:} $options(-peer) { } peer
	fconfigure $d(socket) -translation binary -blocking 0 -buffering none -remote $peer
	fileevent $d(socket) readable [mymethod rx-recv-first]
    }

    method hl-start {} {
	puts "hl-start"
	set d(stopped) 0
	# start the hardware
	if {$d(socket) ne {}} {
	    puts -nonewline $d(socket) [binary format Ia60 [expr {0xeffe0401 | ($options(-bandscope)<<1)}] {}]
	    # puts "hl-start: enabled hardware"
	}
	# instantiate the iqhandler
	install iqhandler using sdrtcl::hl-udp-jack $self.iqhandler -speed $options(-speed) -n-rx $options(-n-rx) {*}$options(-args)
	# puts "hl-start speed [$self.iqhandler cget -speed] [expr {[$self.iqhandler cget -speed]&3}]"
	# puts "hl-start iq config:\n [join [$self.iqhandler configure] \n]"
	# start the iqhandler
	# $self.iqhandler activate
	# puts "hl-start: installed iqhandler"
    }
    
    method hl-stop {} {
	puts "hl-stop"
	set d(time-stop) [clock microseconds]
	if {[info exists d(time-start)]} {
	    set d(pending) [$self pending]
	    set elapsed_us [expr {$d(time-stop)-$d(time-start)}]
	    puts "rx rate [expr {double($d(rx-frames))/$elapsed_us*1e6}], tx rate [expr {double($d(tx-frames))/$elapsed_us*1e6}]"
	    # puts "crash iq config:\n [join [$self.iqhandler configure] \n]"
	}
	# tell hl2 hardware to stop
	if {$d(socket) ne {}} {
	    puts -nonewline $d(socket) [binary format Ia60 0xeffe0400 {}]
	}
	# save iqhandler state
	if {[info procs $self.iqhandler] ne {}} {
	    set options(-args) [concat {*}[lmap x [$self.iqhandler configure] { if {[llength $x] != 5} continue; list [lindex $x 0] [lindex $x 4] }]]
	    # stop iqhandler
	    $self.iqhandler deactivate
	    # delete iqhandler
	    rename $self.iqhandler {}
	}
	set d(stopped) 1
    }    
    method hl-restart {} {
	puts "hl-restart"
	$self hl-stop
	$self tx-reset
	$self rx-reset
	$self stats-reset
	$self hl-start
    }
    
    # these configuration options require a restart
    # could worry about whether they change or not
    method hl-conf {opt val} {
	puts "hl-conf $opt $val"
	set options($opt) $val
	switch -exact -- $opt {
	    -n-rx {
		set d(rx-frames-per-call) [expr {2*int((8*63)/(6*$val+2))}]
	    }
	}
	## this should ideally happen after the change in speed or n-rx has been communicated.
	set d(restart-requested) 1
    }
    
    proc pkt-format {hex} {
	set hex [lmap x $hex {format %02x [expr {$x&0xFF}]}]
	return "[join [lrange $hex 0 2] {}] [lindex $hex 3] [join [lrange $hex 4 end] {}]"
    }
    proc pkt-report {who data} {
	binary scan $data c8c8x504c8x504 preamble header1 header2
	puts "$who [pkt-format $preamble] [pkt-format $header1] ... [pkt-format $header2] ..." 
    }
    ##
    ## tx - transmitter
    ##
    method tx-constructor {} {
	puts "tx-constructor"
    }
    method tx-reset {} {
	puts "tx-reset"
    }
    proc tx-cformat {bits} {
	return [regsub {([01]{7})([01])([01]{8})([01]{8})([01]{8})([01]{8})} $bits {|\1|\2|\3|\4|\5}]
	# return "|[regsub -all {........} $bits {&|}]"
    }
    method tx-send {data} {
	if {$data ne {}} {
	    #binary scan $data IIx3B40x504x3B40x504 syncep seq c1 c2
	    #puts "tx-send [format %x %d $syncep $seq] [tx-cformat $c1] [tx-cformat $c2]"
	    #pkt-report tx-send $data
	    incr d(tx-calls)
	    incr d(tx-frames) 126
	    puts -nonewline $d(socket) $data
	}
	if {$d(restart-requested)} {
	    puts "tx-send restart-requested"
	    set d(restart-requested) 0
	    #$self hl-stop
	    after 1 [mymethod hl-restart]
	    #$self hl-restart
	    return
	}
    }
    
    ##
    ## rx - receiver
    ##
    method rx-constructor {} {
	puts "rx-constructor"
    }
    method rx-reset {} {
	puts "rx-reset"
	set spurs 0
	if {$d(socket) ne {}} {
	    foreach i {1 2} {
		while {[read $d(socket)] ne {}} {
		    incr spurs
		}
		after 1
	    }
	    while {[read $d(socket)] ne {}} {
		incr spurs
	    }
	}
	if {$spurs > 0} { puts "rx-reset: $spurs spurious buffers" }
    }
    method rx-recv-first {} {
	fileevent $d(socket) readable [mymethod rx-recv]
	set d(time-start) [clock microseconds]
	$self rx-recv 
    }
    method rx-recv {} {
	while {1} {
	    set data [read $d(socket)]
	    set n [string length $data]
	    if {$n eq 0} { 
		return 0
	    } elseif {$d(stopped)} {
		incr d(rx-dropped)
		puts "rx-recv: drop packet size $n because stopped"
	    } elseif {$n != 1032} {
		incr d(rx-dropped)
		puts "rx-recv: unknown size, [as-hex $data]"
	    } elseif {[binary scan $data II syncep seq] != 2} {
		# scanned the preamble
		incr d(rx-dropped)
		puts "rx-recv: metis scan failed, [as-hex $data]"
	    } elseif {($syncep&0xFFFFFF00) != 0xeffe0100} {
		incr d(rx-dropped)
		puts "rx-recv: metis sync bytes wrong: [format 0x08x $syncep], [as-hex $data]"
	    } else {
		#pkt-report rx-recv $data
		set ep [expr {$syncep&0xFF}]
		switch $ep {
		    6 { # iq data
			if {[catch {
			    incr d(rx-calls)
			    incr d(rx-frames) $d(rx-frames-per-call)
			    # puts "rx-recv iq $seq [$self.iqhandler pending] $d(rx-calls) $d(rx-frames) $d(tx-calls) $d(tx-frames) $d(bs-calls) $d(bs-frames)"
			    $self tx-send [$self.iqhandler rxiq $data]
			} error]} {
			    set einfo $::errorInfo
			    $self hl-stop
			    error $error $einfo
			}
		    }
		    4 { # bandscope samples
			incr d(bs-calls)
			# puts "rx-recv bs [$self.iqhandler pending] $d(rx-calls) $d(tx-calls) $d(bs-calls)"
			{*}$options(-bs) $data		    
		    }
		    default {
			puts "rx-recv: unknown endpoint $ep, [as-hex $data]"
		    }
		}
	    }
	}
	return [$self rx-recv]
    }	
    ##
    ##
    ##
    method pending {} {
	if {[info procs $self.iqhandler] ne {}} {
	    return [$self.iqhandler pending]
	} else {
	    return {}
	}
    }
    ##
    ## statistics on buffers sent and received
    ##
    method stats-reset {} {
	puts "stats-reset"
	array set d {
	    rx-calls 0 tx-calls 0 bs-calls 0 rx-frames 0 tx-frames 0 bs-frames 0
	}
    }
    
    method stats-rx {} { return [concat {*}[lmap x {calls} {list rx-$x $d(rx-$x)}]] }
    method stats-tx {} { return [concat {*}[lmap x {calls} {list tx-$x $d(tx-$x)}]] }
    method stats-bs {} { return [concat {*}[lmap x {calls} {list bs-$x $d(bs-$x)}]] }
    
    method info-option {opt} {
	if {[info exists optiondocs($opt)]} {
	    return $optiondocs($opt)
	}
	return [$self.iqhandler info option $opt]
    }

    #
    # main constructor
    #
    constructor {args} {
	puts "constructor {$args}"
	# pick off the -n-rx and the -speed options
	set options(-speed) [from args -speed 48000]
	set options(-n-rx) [from args -n-rx 1]
	set options(-peer) [from args -peer {}]
	set options(-args) $args
	# $self configurelist $args
	$self tx-constructor
	$self rx-constructor
	$self stats-reset
	$self hl-begin
    }
}


