# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2019 by Roger E Critchlow Jr, Santa Fe, NM, USA
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
package provide sdrtcl::hl-udp 1.0.0

package require snit
package require udp

namespace eval ::sdrtcl {}

#
# hl - hermes-lite udp manager
# discovers the hermes-lite
# establishes connection
# receives rx-iq and bandscope packets
# extracts control information
# dispatches payloads
# receives rx-iq data
# formats control information
# sends tx-iq packets
# makes incoming and outgoing
# control information available 
# as configure options
#
snit::type sdrtcl::hl-udp {
    # local procedures
    # make a string into a list of bytes
    proc bytes-of {str} {
	binary scan $str c* bytes
	return $bytes
    }
    # map a list of byte values as hex
    proc as-hex {bytes} {
	set hex {}
	foreach b $bytes { lappend hex [format %02x [expr {$b&0xff}]] }
	return $hex
    }
    # map a list of byte values as a mac address
    proc as-mac {bytes} {
	return [join [as-hex $bytes] :]
    }
    # map a list of byte values as binary
    proc as-bin {bytes} {
	set bin {}
	foreach b $bytes { lappend bin [format %08b [expr {$b&0xff}]] }
	return $bin
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
	discover-tries 0
	socket {}
	stopped 1

	iq-sequence 0
	bs-sequence 0
	bs-buff {}
	tx-sequence 0
	tx-index 0
	tx-cached { -mox -speed -filters -not-sync -lna-db -n-rx -duplex 
	    -f-tx -f-rx1 -f-rx2 -f-rx3 -f-rx4 -f-rx5 -f-rx6 -f-rx7
	    -level -vna -pa -low-pwr -pure-signal
	}
    }

    #
    # options
    #
    # options can be passed into the constructor,
    # adjusted with configure, and accessed with cget.
    # options marked -readonly true are either
    # set in the constructor, 
    # or are derived from hardware
    # and can only be accessed with cget
    #

    # these are used to direct the discovery phase
    option -broadcast-addrs -default {} -readonly true
    option -port -default 1024 -readonly true
    option -discover-timeout -default 1000 -readonly true
    option -discover-retries -default 5 -readonly true

    # these are discovered during connection to the hl
    option -code-version -default -1 -type snit::integer -readonly true
    option -board-id -default -1 -type snit::integer -readonly true
    option -mac-addr -default {} -readonly true
    option -peer -default {} -readonly true

    # this one enters into the start command
    option -bandscope -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {hl conf}

    # these are used to populate controls in the transmit stream
    option -mox -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    option -speed -default 48000 -type {snit::enum -values {48000 96000 192000 384000}} -configuremethod {tx conf}
    option -filters -default 0 -type {snit::integer -min 0 -max 127} -configuremethod {tx conf}
    option -not-sync -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    option -lna-db -default 20 -type {snit::integer -min -12 -max 48} -configuremethod {tx conf}
    option -n-rx -default 1 -type {snit::integer -min 1 -max 7} -configuremethod {tx conf}
    option -duplex -default 1 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    option -f-tx -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx1 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx2 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx3 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx4 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx5 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx6 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -f-rx7 -default 7012352 -type {snit::integer -min 0} -configuremethod {tx conf}
    option -level -default 0 -type {snit::integer -min 0 -max 255} -configuremethod {tx conf}
    option -pa -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    # Disable T/R 
    option -low-pwr -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    option -pure-signal -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}

    # bias adjustment is tricky
    option -bias-adjust -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}

    # vector network analysis is tricky
    option -vna -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}
    option -vna-count -default 0 -type snit::integer -configuremethod {tx conf}
    option -vna-started -default 0 -type {snit::integer -min 0 -max 1} -configuremethod {tx conf}

    # these are found in receive packets
    option -hw-key -default 0 -type {snit::integer -min 0 -max 1} -readonly true
    option -hw-ptt -default 0 -type {snit::integer -min 0 -max 1} -readonly true
    option -overflow -default 0 -type {snit::integer -min 0 -max 1} -readonly true
    option -serial -default 0 -type {snit::integer -min 0 -max 32767} -readonly true
    option -temperature -default 0 -type {snit::integer -min 0 -max 32767} -readonly true
    option -fwd-power -default 0 -type {snit::integer -min 0 -max 32767} -readonly true
    option -rev-power -default 0 -type {snit::integer -min 0 -max 32767} -readonly true
    option -pa-current -default 0 -type {snit::integer -min 0 -max 32767} -readonly true

    # these sink the sample streams
    # they should accept any number of buffers as arguments
    option -rx -default {};	# output handler: interleaved rx iq and microphone in
    option -bs -default {};	# output handler: raw ADC samples for bandscope

    variable optiondocs -array {
	-broadcast-addrs {The IP addresses sent discovery packets, default constructs a plausible list.}
	-port {The UDP port sent discovery packets.}
	-discover-timeout {The timeout in ms between discovery attempts.}
	-discover-retries {The number of discovery attempts to make.}
	-code-version {The Hermes code version reported by the connected board.}
	-board-id {The board identifier reported by the connected board}
	-mac-addr {The MAC address of the connected board.}
	-peer {The IP address and port of the connected board.}
	-bandscope {Enable the bandscope samples.}
	-mox {Enable transmitter.}
	-speed {Choose speed of IQ samples to be 48000, 96000, 192000, or 384000 samples per second.}
	-filters {Bits which enable filters on the N2ADR filter board.}
	-not-sync {Disable power supply sync.}
	-lna-db {Decibels of low noise amplifier on receive, from -12 to 48.}
	-n-rx {Number of receivers to implement, from 1 to 8 permitted, current HermesLite can do 1 to 4.}
	-duplex {Enable the transmitter frequency to vary independently of the receiver frequencies}
	-f-tx {Transmitter NCO frequency}
	-f-rx1 {Receiver 1 NCO frequency}
	-f-rx2 {}
	-f-rx3 {}
	-f-rx4 {}
	-f-rx5 {}
	-f-rx6 {}
	-f-rx7 {}
	-level {Transmitter power level, from 0 to 255.}
	-pa {Enable power amplifier.}
	-low-pwr {Disable T/R relay in low power operation.}
	-pure-signal {Enable Pure Signal operation. Not implemented.}
	-bias-adjust {Enable bias current adjustment for power amplifier. Not implemented}
	-vna {Enable vector network analysis mode. Not implemented.}
	-vna-count {Number of frequencies sampled in VNA mode. Not implemented.}
	-vna-started {Start VNA mode. Not implemented.}
	-hw-key {The hardware key value from the HermesLite key/ptt jack.}
	-hw-ptt {The hardware ptt value from the HermesLite key/ptt jack.}
	-overflow {The ADC has clipped values in this frame.}
	-serial {The Hermes software serial number}
	-temperature {Raw ADC value for temperature sensor.}
	-fwd-power {Raw ADC value for forward power sensor.}
	-rev-power {Raw ADC value for reverse power sensor.}
	-pa-current {Raw ADC value for power amplifier current sensor.}
	-rx {The handler for received buffers of IQ samples.}
	-bs {The handler for received buffers of raw bandscope samples.}
    }
    # tx samples are provided by calling 'hl tx send buffer1 buffer2'
    # when there are sufficient samples to provide 504 bytes for each buffer
    # the samples are interleaved stereo audio out and transmit IQ
    # 8 bytes per frame (I, Q, L, R), 2 bytes per sample, big-endian, signed

    ##
    ## hermes lite / metis discovery
    ##
    method {discovery start} {} {
	if {$options(-broadcast-addrs) eq {}} {
	    # if we have not been given an explicit list of broadcast address
	    # then we construct one
	    set options(-broadcast-addrs) [concat [exec ip addr | awk {/inet .*brd/{ print $4 }}] 255.255.255.255]
	}
	set d(discovery) 0
	set d(discover-tries) 0
	set socket [udp_open]
	fconfigure $socket -translation binary -blocking 0 -buffering none -broadcast 1
	fileevent $socket readable [mymethod discovery response $socket]
	$self discovery send $socket
    }
    method {discovery send} {socket} {
	foreach addr $options(-broadcast-addrs) {
	    fconfigure $socket -remote [list $addr $options(-port)]
	    # no idea why this is a 63 byte packet instead of 64
	    puts -nonewline $socket [binary format Ia59 {0xeffe0200} {}]
	}
	after $options(-discover-timeout) [mymethod discovery timeout $socket]
	incr d(discover-tries)
    }
    method {discovery response} {socket} {
	set data [read $socket]
	set peer [fconfigure $socket -peer]
	set n [binary scan $data Scc6cc effe status metis_mac_address code_version board_id]
	if {$n != 5} { puts "discovery response: $n items scanned in response" }
	if {($effe&0xffff) != 0xeffe} { 
	    puts "discovery response: sync bytes are [format %04x $effe]?"
	}
	# puts "discovery response: {$peer} $status [as-mac $metis_mac_address] $code_version $board_id"
	set options(-peer) $peer
	set options(-mac-addr) [as-mac $metis_mac_address]
	set options(-code-version) $code_version
	set options(-board-id) $board_id
	if {$status == 2} {
	    set d(discovery) 1
	    after 1 [mymethod hl begin]
	} else {
	    puts "discovery response: $peer is already busy"
	}
    }
    method {discovery timeout} {socket} {
	if {$d(discovery)} {
	    close $socket
	} elseif {$d(discover-tries) >= $options(-discover-retries)} {
	    close $socket
	    puts "abandoning hl discovery"
	} else {
	    $self discovery send $socket
	}
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

    #
    # values of the c1 .. c4 bytes of controls as a bigendian integer for index 0 .. 18
    # so the options don't get initialized with the default values,
    # so these values don't get initialized, sucks that I need to replicate the
    # computations in two places
    # 
    variable c1234 -array {
	0 0 1 0 2 0 3 0 4 0 5 0 6 0 7 0 8 0 9 0 10 0 11 0 12 0 13 0 14 0 15 0 16 0 17 0 18 0
    }

    method {tx constructor} {} {
	# reconfigure with default values to load control cache
	foreach opt $d(tx-cached) {
	    $self configure $opt [$self cget $opt]
	}
	set d(restart-requested) 0
    }

    method {tx conf} {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -mox {}
	    -speed { 
		set c1234(0) [expr {($c1234(0) & ~(3<<24)) | ([map-speed $val]<<24)}] 
		incr d(restart-requested)
	    }
	    -filters {
		set c1234(0) [expr {($c1234(0) & ~(127<<17)) | ($val<<17)}]
	    }
	    -not-sync {
		set c1234(0) [expr {($c1234(0) & ~(1<<12)) | ($val<<12)}]
	    }
	    -lna-db {
		set c1234(10) [expr {($c1234(10) & ~0x7F) | 0x40 | ($val+12)}]
	    }
	    -n-rx {
		set c1234(0) [expr {($c1234(0) & ~(7<<3)) | (($val-1)<<3)}]
		incr d(restart-requested)
	    }
	    -duplex {
		set c1234(0) [expr {($c1234(0) & ~(1<<2)) | ($val<<2)}]
	    }
	    -f-tx { set c1234(1) $val }
	    -f-rx1 { set c1234(2) $val }
	    -f-rx2 { set c1234(3) $val }
	    -f-rx3 { set c1234(4) $val }
	    -f-rx4 { set c1234(5) $val }
	    -f-rx5 { set c1234(6) $val }
	    -f-rx6 { set c1234(7) $val }
	    -f-rx7 { set c1234(8) $val }
	    -level {
		# c0 index 9, C1 entire
		set c1234(9) [expr {($c1234(9) & ~(0xFF<<24)) | ($val<<24)}]
	    }
	    -vna {
		# C0 index 9, C2 & 0x80
		set c1234(9) [expr {($c1234(9) & ~(1<<23)) | ($val<<23)}]
	    }
	    -pa {
		# C0 index 9, C2 & 0x08
		set c1234(9) [expr {($c1234(9) & ~(1<<19)) | ($val<<19)}]
	    }
	    -low-pwr {
		# C0 index 9, C2 & 0x04
		set c1234(9) [expr {($c1234(9) & ~(1<<18)) | ($val<<18)}]
	    }
	    -pure-signal {
		# C0 index 10, C2 & 0x40
		set c1234(10) [expr {($c1234(10) & ~(1<<22)) | ($val<<22)}]
	    }
	}
    }

    # generate the control bytes for header $index
    method {tx control} {} { 
	set index $d(tx-index)
	set d(tx-index) [expr {($d(tx-index)+1)%19}]
	return [binary format cI [expr {($index<<1)|$options(-mox)}] $c1234($index)]
    }
    
    method {tx reset} {} {
	set d(tx-index) 0
	set d(tx-sequence) 0
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
	# puts "tx send: pkt [as-hex [lrange [bytes-of $pkt] 0 24]] ..."
    }

    ##
    ## rx - receiver
    ##
    method {rx constructor} {} {
	# deal with missing -rx and -bs handlers
	if {$options(-rx) eq {}} { set options(-rx) [mymethod dummy rx] }
	if {$options(-bs) eq {}} { set options(-bs) [mymethod dummy bs] }
    }

    # record options which have been updated
    # by the hardware since last polled
    variable rxupdates -array {}
    
    method {rx update} {opt val} {
	if {$options($opt) != $val} {
	    set options($opt) $val
	    incr rxupdates($opt)
	}
    }

    # return the list of updated rx options
    # and clear the update flags
    # in all honesty, they are going to change
    # all the time, except for -hw-key and -hw-ptt
    method {rx updated} {} {
	set upd {}
	foreach opt [array names rxupdated] {
	    set rxupdated($opt) 0
	    lappend upd $opt
	}
	return $upd
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
	    if {$d(stopped)} continue
	    if {$n != 1032} {
		if {$n != 0} {
		    binary scan $data c* bytes
		    puts "rx readable: unknown packet size $n: [as-hex $bytes]"
		}
		return
	    }
	    if {[binary scan $data IIa512a512 syncep seq f1 f2] != 4} {
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
		    if {$seq > $d(iq-sequence)} {
			puts "rx readable: received iq packet $seq at $d(iq-sequence), jumping ahead"
			set d(iq-sequence) $seq
		    }
		    if {$seq == $d(iq-sequence)} {
			incr d(iq-sequence)
			set iq {}
			foreach f [list $f1 $f2] {
			    if {[binary scan $f IIa504 s123c0 I1234 b] != 3} {
				puts "rx readable: usb scan failed"
				return
			    }
			    if {($s123c0&0xFFFFFF00)  != 0x7f7f7f00} {
				puts "rx readable: usb sync bytes wrong: [format 0x%08x $s123c0]"
				return
			    }
			    # scan control bytes into option values
			    set c0 [expr {($s123c0&0xFF)}]
			    switch $c0 {
				0 - 1 - 2 - 3 {
				    $self rx update -hw-key [expr {($c0&2) != 0}]
				    $self rx update -hw-ptt [expr {($c0&1) != 0}]
				    $self rx update -overflow [expr {($I1234&(1<<24)) != 0}]
				    $self rx update -serial [expr {$I1234&0xFF}]
				}
				8 {
				    $self rx update -temperature [expr {($I1234>>16)&0xffff}]
				    $self rx update -fwd-power [expr {$I1234&0xffff}]
				}
				16 {
				    $self rx update -rev-power [expr {($I1234>>16)&0xffff}]
				    $self rx update -pa-current [expr {$I1234&0xffff}]
				}
				24 {
				}
				32 {
				}
				40 {
				}
				251 - 252 - 253 {
				    # these are acks to i2c settings
				    # need to post the ack to the tx
				    # control queue
				}
				default {
				    error "rx"
				}
			    }
			    # send data on
			    lappend iq $b
			}
			incr d(rx-calls)
			set n [expr {[string length [lindex $iq 0]]+[string length [lindex $iq 1]]}]
			incr d(rx-bytes) $n
			set ns [expr {int($n/($::options(-n-rx)*6+2))}]
			incr d(rx-samples) $ns
			set in [{*}$options(-rx) {*}$iq]
			if {[llength $in] == 2} {
			    $self tx send {*}$in
			}
		    } else {
			puts "rx readable: received iq packet $seq at $d(iq-sequence)"
		    }
		}
		4 {
		    # bandscope samples
		    if {$seq == $d(bs-sequence)} {
			incr d(bs-sequence)
			set i [expr {$seq & 3}]
			if {[llength $d(bs-buff)] != 2*$i} {
			    set d(bs-buff) {}
			    puts "rx readable: truncating bandscope buffer"
			} else {
			    lappend d(bs-buff) $f1 $f2
			    if {$i == 3} {
				incr d(bs-calls)
				set n 0
				foreach b $d(bs-buff) { incr n [string length $b] }
				incr d(bs-bytes) $n
				incr d(bs-samples) [expr {$n/2}]
				{*}$options(-bs) {*}$d(bs-buff)
				set d(bs-buff) {}
			    }
			}
		    } else {
			# ignore
			# puts "readable received bs packet $seq at $d(bs-sequence)"
		    }
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
    method {dummy rx} {b1 b2} {
	incr d(dummy-rx-calls)
	incr d(dummy-rx-bytes)
	set n [expr {[string length $b1]+[string length $b2]}]
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
	$self discovery start
    }
}
    
    
