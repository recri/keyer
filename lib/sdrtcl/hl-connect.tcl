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

package require Thread
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
snit::type sdrtcl::hl-connect-thread {
    component iqhandler;	# the rx and tx iq stream(s) handler
    component bshandler;	# the bandscope stream handler
    component discover;		# the discovery phase, optional
    
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
	pending {}
	last-pending {}
    }

    #
    # options
    #

    # these are discovered during connection to the hl
    # most are probably being passed in directly
    option -peer -default {} -configuremethod Configure
    option -code-version -default -1 -type snit::integer -configuremethod Configure
    option -board-id -default -1 -type snit::integer -configuremethod Configure
    option -mac-addr -default {} -configuremethod Configure
    option -mcp4662 -default {} -configuremethod Configure
    option -fixed-ip -default {} -configuremethod Configure
    option -fixed-mac -default {} -configuremethod Configure
    option -n-hw-rx -default -1 -configuremethod Configure
    option -wb-fmt -default -1 -configuremethod Configure
    option -build-id -default -1 -configuremethod Configure
    option -gateware-minor -default -1 -configuremethod Configure

    # -discover allows one to pass the entire output from hl-discover as a quoted string
    # bad, end runs around option value management in dial-set
    option -discover -default {} -configuremethod Discover
    
    # this one enters into the start command
    option -bandscope -default 0 -type {snit::integer -min 0 -max 1} -configuremethod hl-conf

    # these are handled separate from the other hl-udp-jack options
    # because they require restarting the component when they change
    option -speed -default 48000 -configuremethod hl-conf
    option -n-rx -default 1 -configuremethod hl-conf

    # these are just raw values copied from the hardware interface
    option -overload -default 0 -readonly 1;		# rx index 0
    option -recovery -default 0 -readonly 1;		# rx index 0
    option -tx-iq-fifo -default 0 -readonly 1;		# rx index 0

    # the raw values need to be averaged over multiple readings
    # and translated into sensible units
    # the averaged values are available via these options
    option -avg-temperature -default 0 -readonly 1;	# rx index 1
    option -avg-fwd-power -default 0 -readonly 1;	# rx index 1
    option -avg-rev-power -default 0 -readonly 1;	# rx index 2
    option -avg-pa-current -default 0 -readonly 1;	# rx index 2
    # the converted average values are available via these options
    option -temperature -default 0 -readonly 1
    option -fwd-power -default 0 -readonly 1
    option -rev-power -default 0 -readonly 1
    option -pa-current -default 0 -readonly 1 
    option -swr -default 100 -readonly 1
    option -power -default 0 -readonly 1

    # pure performance statistics, 
    # updated at each received packet
    # reset when the connection is restarted
    option -rx-calls -default 0 -readonly 1
    option -tx-calls -default 0 -readonly 1
    option -bs-calls -default 0 -readonly 1
    option -rx-dropped -default 0 -readonly 1
    option -rx-outofseq -default 0 -readonly 1
    option -rx-frames-per-call -default 126 -readonly 1
    option -tx-frames-per-call -default 126 -readonly 1
    option -bs-frames-per-call -default 512 -readonly 1

    # the rest of the options are delegated to the iqhandler component directly
    delegate option * to iqhandler
    delegate method activate to iqhandler

    variable optiondocs -array {
	-discover {One of the results of hl-discover describing available hardware.}
	-peer {The IP address and port of the connected board.}
	-mac-addr {The MAC address of the connected board.}
	-code-version {The Hermes code version reported by the connected board.}
	-board-id {The board identifier reported by the connected board}

	-bandscope {Enable the bandscope samples.}
	
	-speed {Choose speed of IQ samples to be 48000, 96000, 192000, or 384000 samples per second.}
	-n-rx {Number of receivers to implement, from 1 to 8 permitted, current HermesLite can do 1 to 4.}

	-avg-temperature {Running average of temperature ADC readings.}
	-avg-fwd-power {Running average of forward power ADC readings.}
	-avg-rev-power {Running average of reverse power ADC readings.}
	-avg-pa-current {Running average of PA current ADC readings.}

	-temperature {Temperature (degrees Celsius)}
	-fwd-power {Forward power (Watts)}
	-rev-power {Reverse power (Watts)}
	-pa-current {PA current (mA)}

	-rx-calls {Number of IQ packets received from HL2.}
	-tx-calls {Number of IQ packets sent to HL2.}
	-bs-calls {Number of bandscope packets received from HL2.}
	-rx-dropped {Number of received packets dropped.}
	-rx-outofseq {Number of out of sequence packets received.}
	-rx-frames-per-call {Number of RX IQ samples received per rx-call}
	-tx-frames-per-call {Number of TX IQ samples sent per tx-call}
	-bs-frames-per-call {Number of bandscope samples per bs-call}

	-overload {The ADC has clipped values in this frame.}
	-recovery {Buffer under/overlow recovery active.}
	-tx-iq-fifo {TX IQ FIFO Count MSBs.}
	
	-swr {Standing wave ratio}
	-power {Power output}
    }

    method info-option {opt} {
	if {[info exists optiondocs($opt)]} {
	    return $optiondocs($opt)
	}
	return [$iqhandler info option $opt]
    }

    ##
    ## hl - hermes lite / metis start stop socket handlers
    ## so we want to start the main component before we start the socket handlers
    ##
    method hl-begin {} {
	# puts "hl-begin"
	set d(stopped) 1
	if {$d(socket) ne {}} {
	    puts -nonewline $d(socket) [binary format Ia60 0xeffe0400 {}]
	    close $d(socket)
	}
	set d(socket) [udp_open]
	regsub {:} $options(-peer) { } peer
	# puts "$options(-peer) translated to $peer, socket $d(socket)"
	fconfigure $d(socket) -translation binary -blocking 0 -buffering none -remote $peer
	fileevent $d(socket) readable [mymethod rx-recv-discard]
	# puts "hl-begin: set buffer handler rx-recv-discard"
	$self rx-reset
	$self hl-restart
    }

    method hl-start {} {
	# puts "hl-start"
	set d(stopped) 0
	# start the hardware
	puts -nonewline $d(socket) [binary format Ia60 [expr {0xeffe0401 | ($options(-bandscope)<<1)}] {}]
	set d(time-kick) [clock microseconds]
	puts "hl-start: enabled hardware"
	# instantiate the iqhandler
	# install iqhandler using sdrtcl::hl-udp-jack $iqhandler -speed $options(-speed) -n-rx $options(-n-rx) {*}$options(-args)
	# puts "hl-start speed [$iqhandler cget -speed] [expr {[$iqhandler cget -speed]&3}]"
	# puts "hl-start iq config:\n [join [$iqhandler configure] \n]"
	# start the iqhandler
	$iqhandler activate
	# puts "hl-start: activated iqhandler"
	# enable live buffer handler
	fileevent $d(socket) readable [mymethod rx-recv-first]
	# puts "hl-start: set buffer handler rx-recv-first"
    }
    
    method hl-stop {} {
	# puts "hl-stop"
	set d(time-stop) [clock microseconds]
	if {[info exists d(time-start)]} {
	    set d(pending) [$self pending]
	    set elapsed_us [expr {$d(time-stop)-$d(time-start)}]
	    puts "rx rate [expr {double($options(-rx-frames-per-call)*$options(-rx-calls))/$elapsed_us*1e6}]"
	    puts "tx rate [expr {double($options(-tx-frames-per-call)*$options(-tx-calls))/$elapsed_us*1e6}]"
	    # puts "crash iq config:\n [join [$iqhandler configure] \n]"
	}
	# tell hl2 hardware to stop
	puts -nonewline $d(socket) [binary format Ia60 0xeffe0400 {}]
	# puts "hl-stop: disabled hardware"
	# save iqhandler state
	set options(-args) [$self hl-filter-options [$iqhandler configure]]
	puts "hl-stop: saved options $options(-args)"
	# stop iqhandler
	$iqhandler deactivate
	# puts "hl-stop: deactivate iqhandler"
	# delete iqhandler
	rename $self.iqhandler {}
	# puts "hl-stop: delete iqhandler"
	# reinstall a new iqhandler
	install iqhandler using sdrtcl::hl-udp-jack $iqhandler -client [namespace tail $self] {*}$options(-args)
	# puts "hl-stop: recreate iqhandler"
	set d(stopped) 1
    }    
    method hl-restart {} {
	# puts "hl-restart"
	$self hl-stop
	$self rx-reset
	$self hl-start
    }
    
    # these configuration options require a restart
    # could worry about whether they change or not
    method hl-conf {opt val} {
	# puts "hl-conf $opt $val"
	set options($opt) $val
	switch -exact -- $opt {
	    -n-rx { set options(-rx-frames-per-call) [expr {2*int((8*63)/(6*$val+2))}] }
	}
	## this should ideally happen after the change in speed or n-rx has been communicated.
	set d(restart-requested) 1
    }
    
    method hl-filter-options {config} {
	set f {}
	foreach x $config {
	    # an alias, not a real configuration option
	    if {[llength $x] != 5} continue
	    # split the parts of the configuration out
	    foreach {opt name xclass dvalue cvalue} $x break
	    # default value need not be kept
	    if {$dvalue == $cvalue} continue
	    # readonly options from radio can be skipped
	    if {$opt in {-hw-dash -hw-dot -hw-ptt -overload -recovery -tx-iq-fifo -serial -temperature -fwd-power -rev-power -pa-current}} continue
	    # noise options from discovery can be skipped
	    if {$opt in {}} continue
	    lappend f $opt $cvalue
	}
	return $f
    }
    method {Discover -discover} {val} {
	puts "hl-connect configure -discover {$val}"
	if {$val eq {discover}} {
	    install discover using sdrtcl::hl-discover $self.discover
	    set val [lindex [$discover discover] 0]
	    puts "hl-discover returned $val"
	}
	set status [from val -status]
	if {$status != 2} { error "-discover specifies a hermes lite with -status $status" }
	after 250 [mymethod configurelist $val]
    }
    method Configure {opt val} {
	set options($opt) $val
	catch {$iqhandler configure $opt $val}
	if {$opt eq {-peer}} { after 1 [mymethod hl-begin] }
    }
    
    proc pkt-format {hex} {
	# the packet headers are formatted as 3 bytes sync, 5 bytes payload
	# both at the UDP packet and the USB packet layers.
	# the first byte of UDP payload is the endpoint, the next four are sequence number
	# the first byte of USB payload is (index << n) | bits, the next four depend on index
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
    proc tx-cformat {bits} {
	return [regsub {([01]{7})([01])([01]{8})([01]{8})([01]{8})([01]{8})} $bits {|\1|\2|\3|\4|\5}]
	# return "|[regsub -all {........} $bits {&|}]"
    }
    method tx-send {data} {
	if {$data ne {}} {
	    #binary scan $data IIx3B40x504x3B40x504 syncep seq c1 c2
	    #puts "tx-send [format %x %d $syncep $seq] [tx-cformat $c1] [tx-cformat $c2]"
	    #pkt-report tx-send $data
	    incr options(-tx-calls)
	    puts -nonewline $d(socket) $data
	}
	if {$d(restart-requested)} {
	    # puts "tx-send restart-requested"
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
    method rx-reset {} {
	# puts "rx-reset"
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
    method rx-recv-discard {} {
	while {1} {
	    set data [read $d(socket)]
	    if {[string length $data] == 0} return
	}
    }
    
    method rx-recv-first {} {
	fileevent $d(socket) readable [mymethod rx-recv]
	set d(time-start) [clock microseconds]
	puts "hl-connect rx-recv-first [expr {$d(time-start)-$d(time-kick)}] usec from udp start command"
	$self rx-recv 
    }
    method rx-recv {} {
	# puts "hl-connect rx-recv"
	while {1} {
	    set data [read $d(socket)]
	    set n [string length $data]
	    if {$n eq 0} { 
		return 0
	    } elseif {$d(stopped)} {
		incr options(-rx-dropped)
		puts "rx-recv: drop packet size $n because stopped"
	    } elseif {$n != 1032} {
		incr options(-rx-dropped)
		puts "rx-recv: unknown size, [as-hex $data]"
	    } elseif {[binary scan $data IIIx508Ix508 syncep seq usb1 usb2] != 4} {
		# scanned the preamble
		incr options(-rx-dropped)
		puts "rx-recv: metis scan failed, [as-hex $data]"
	    } elseif {($syncep&0xFFFFFF00) != 0xeffe0100} {
		incr options(-rx-dropped)
		puts "rx-recv: metis sync bytes wrong: [format 0x08x $syncep], [as-hex $data]"
	    } else {
		#pkt-report rx-recv $data
		set ep [expr {$syncep&0xFF}]
		switch $ep {
		    6 { # iq data
			# if {$seq < 10} { puts "rx-recv $seq" }
			if {[catch {
			    incr options(-rx-calls)
			    set pending [$iqhandler pending]
			    if {[lindex [lindex $pending 1] 2] ne {} || 
				[lindex [lindex $pending 2] 2] ne {} ||
				($seq % 5000) == 0} { 
				puts "rx-recv $seq $pending"
			    }
			    $self tx-send [$iqhandler rxiq $data]
			    # these might be deferred to after idle
			    $self rx-postprocess-[expr {($usb1>>3)&0x1F}]
			    $self rx-postprocess-[expr {($usb2>>3)&0x1f}]
			} error]} {
			    set einfo $::errorInfo
			    $self hl-stop
			    error $error $einfo
			}
			# puts stderr "[expr {[clock microseconds]-$d(time-start)}] [$iqhandler pending]"
		    }
		    4 { # bandscope samples
			incr options(-bs-calls)
			# puts "rx-recv bs [$iqhandler pending] $options(-rx-calls) $options(-tx-calls) $options(-bs-calls)"
			{*}$options(-bs) $data		    
		    }
		    default {
			puts "rx-recv: unknown endpoint $ep, [as-hex $data]"
		    }
		}
	    }
	}
    }	

    # post process values received in rx packets
    # some things just get copied down to here so we can set variable traces on the options array
    # raw ADC readings get a decayed average computed and an approximation to the real value computed

    # this 'power' formula is a polynomial fit to quisk's calibration table
    proc power {x} { return [expr {1.132e-02 + $x * (2.025e-05 + $x * 4.298e-07)}] }
    proc swr {fwd rev} {
	# Which voltage is forward and reverse depends on the polarity of the current sense transformer
	if {$fwd < $rev} { return [swr $rev $fwd] }
	set power [format %3.1f [expr {max(0, $fwd - $rev)}]]
	if {$fwd >= 0.05} {
	    set gamma [expr {sqrt($rev / $fwd)}]
	    if {$gamma < 0.98} {
		set swr [expr {(1.0 + $gamma) / (1.0 - $gamma)}]
	    } else {
		set swr 99.0
	    }
	    if {$swr < 9.95} {
		set swr [format "%4.2f" $swr]
	    } else {
		set swr [format "%4.0f" $swr]
	    }
	} else {
	    set swr "---"
	}
	return [list $power $swr]
    }

    method rx-postprocess-0 {} {
	set options(-overload) [$iqhandler cget -raw-overload]
	set options(-recovery) [$iqhandler cget -raw-recovery]
	set options(-tx-iq-fifo) [$iqhandler cget -raw-tx-iq-fifo]
    }
    # temp = (3.26 * (AIN[4] / 4096.0) - 0.5) / 0.01
    # current = (((3.26 * (AIN[2] / 4096.0)) / 50.0) / 0.04 * 1000 * 1270 / 1000)
    # power = 1.132e-02 + x * (2.025e-05 + x * 4.298e-07)
    method rx-postprocess-1 {} {
	set options(-avg-temperature) [expr {($options(-avg-temperature)+[$iqhandler cget -raw-temperature])>>1}]
	set options(-avg-fwd-power) [expr {($options(-avg-fwd-power)+[$iqhandler cget -raw-fwd-power])>>1}]
	set options(-temperature) [expr {(3.26 * ($options(-avg-temperature)/4096.0) - 0.5)/0.01}]
	set options(-fwd-power) [power $options(-avg-fwd-power)]
    }
    method rx-postprocess-2 {} {
	set options(-avg-rev-power) [expr {($options(-avg-rev-power)+[$iqhandler cget -raw-rev-power])>>1}]
	set options(-avg-pa-current) [expr {($options(-avg-pa-current)+[$iqhandler cget -raw-pa-current])>>1}]
	set options(-rev-power) [power $options(-avg-rev-power)]
	set options(-pa-current) [expr {(((3.26 * ($options(-avg-pa-current)/4096.0))/50.0)/0.04)/(1000.0/1270.0)}]
	lassign [swr $options(-fwd-power) $options(-rev-power)] options(-power) options(-swr)
    }
    method rx-postprocess-3 {} {
    }
    method rx-postprocess-4 {} {
    }
    method rx-postprocess-5 {} {
    }
    ##
    ##
    ##
    method pending {} {
	catch {$iqhandler pending} result
	return $result
    }

    method is-busy {} { return 0 }

    #
    # main constructor
    #
    constructor {args} {
	puts "constructor {$args}"
	install iqhandler using sdrtcl::hl-udp-jack $self.iqhandler -client hl
	$self configurelist $args
	array set options {-rx-calls 0 -tx-calls 0 -bs-calls 0 -rx-dropped 0 -rx-outofseq 0}
    }
}

#
# hl-connect shell that proxies to the code above running in its own thread
#
snit::type sdrtcl::hl-connect {
    variable id
    variable name ::hlt
    variable result
    pragma -hasinfo false
    constructor {args} {
	set id [thread::create -joinable -preserved]
	thread::send $id [list lappend auto_path ~/keyer/lib]
	thread::send $id [list package require sdrtcl::hl-connect]
	thread::send $id [list sdrtcl::hl-connect-thread $name {*}$args]
    }
    destructor {
	catch {$self send $name hl-stop}
	while {[thread::release $id] > 0} {}
	thread::join $id
    }
    method configure {args} {
	if {$args eq {}} {
	    return [thread::send $id [list $name configure]]
	}
	if {[llength $args] == 1} {
	    return [thread::send $id [list $name configure [lindex $args 0]]]
	}
	return [thread::send $id [list $name configurelist $args]]
    }
    method configurelist {list} { return [thread::send $id [list $name configurelist $list]] }
    method cget {opt} {           return [thread::send $id [list $name cget $opt]] }
    method cset {opt val} {       return [thread::send $id [list $name cset $opt $val]] }
    method info {args} {          return [thread::send $id [list $name info {*}$args]] }
    method info-option {opt} {    return [thread::send $id [list $name info-option $opt]] }
    method activate {} {          return [thread::send $id [list $name activate]] }
    method deactivate {} {        return [thread::send $id [list $name deactivate]] }
    method is-active {} {         return [thread::send $id [list $name is-active]] }
    method is-busy {} {           return [thread::send $id [list $name is-busy]] }
    method pending {} {           return {} }
}



