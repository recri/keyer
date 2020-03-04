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
package provide sdrtcl::hl-discover 0.0.1

package require snit
package require udp

namespace eval ::sdrtcl {}

#
# hl-discover - hermes-lite udp discovery
# discovers the hermes-lites on the specified network interfaces
# returns a list of data describing each discovered device
#
set sdrtcl::hl-discover-finished 0

snit::type sdrtcl::hl-discover {
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
    # map a list of values as an ip address
    proc as-ip-addr {bytes} {
	return [join $bytes .]
    }
    # local data
    # keep most of it all in one array
    variable d -array {
	discover-tries 0
	socket {}
	stopped 1
	response {}
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
    option -peer -default {} -readonly true
    option -status -default {} -readonly true
    option -mac-addr -default {} -readonly true
    option -gateware-version -default -1 -type snit::integer -readonly true
    option -board-id -default -1 -type snit::integer -readonly true
    option -mcp4662 -default {} -readonly true
    option -fixed-ip -default {} -readonly true
    option -fixed-mac -default {} -readonly true
    option -n-hw-rx -default -1 -readonly true
    option -wb-fmt -default -1 -readonly true
    option -build-id -default -1 -readonly true
    option -gateware-minor -default -1 -readonly true

    variable optiondocs -array {
	-broadcast-addrs {The IP addresses sent discovery packets, default constructs a plausible list.}
	-port {The UDP port sent discovery packets.}
	-discover-timeout {The timeout in ms between discovery attempts.}
	-discover-retries {The number of discovery attempts to make.}
	-gateware-version {The Hermes code version reported by the connected board.}
	-board-id {The board identifier reported by the connected board}
	-mac-addr {The MAC address of the connected board.}
	-peer {The IP address and port of the connected board.}
    }

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
    # added response information
    # 0x0B	[7:0]	MCP4662 0x06 Config Bits
    # 0x0C	[7:0]	MCP4662 0x07 Reserved Config Bits
    # 0x0D	[7:0]	MCP4662 0x08 Fixed IP
    # 0x0E	[7:0]	MCP4662 0x09 Fixed IP
    # 0x0F	[7:0]	MCP4662 0x0A Fixed IP
    # 0x10	[7:0]	MCP4662 0x0B Fixed IP
    # 0x11	[7:0]	MCP4662 0x0C MAC
    # 0x12	[7:0]	MCP4662 0x0D MAC
    # 0x13	[7:0]	Number of Hardware Receivers
    # 0x14	[7:6]	00 wide band data is 12-bit sign extended two's complement
    #		01 wide band data is 16-bit two's complement
    #	        [5:0]	Board ID: 5, 3 or 2 for build
    # 0x15	[7:0]	Gateware Minor Version/Patch
    method {discovery response} {socket} {
	set data [read $socket]
	set peer [fconfigure $socket -peer]
	if {[string length $data] == 0} {
	    # puts "discovery response: 0 length packet received"
	    return
	}
	set n [binary scan $data Scc6ccc2c4c2ccc effe status metis_mac_address code_version board_id mcp4662_config fixed_ip fixed_mac n_hw_rx wb_fmt_build_id gateware_minor]
	if {$n != 11} {
	    puts "discovery response: $n items scanned in response"
	    return
	}
	if {($effe&0xffff) != 0xeffe} { 
	    puts "discovery response: sync bytes are [format %04x $effe]?"
	    return
	}
	set response [list \
			  -peer [join $peer :] \
			  -status $status \
			  -mac-addr [as-mac $metis_mac_address] \
			  -code-version $code_version \
			  -board-id $board_id \
			  -mcp4662 [join [as-hex $mcp4662_config] :] \
			  -fixed-ip [as-ip-addr $fixed_ip] \
			  -fixed-mac [as-mac $fixed_mac] \
			  -n-hw-rx $n_hw_rx \
			  -wb-fmt [expr {($wb_fmt_build_id >> 6) & 3}] \
			  -build-id [expr {$wb_fmt_build_id & 0x3F}] \
			  -gateware-minor $gateware_minor \
			 ]
	if {[lsearch -exact $d(response) $response] < 0} {
	    lappend d(response) $response
	}
	incr d(discovery)
    }
    method {discovery timeout} {socket} {
	if {$d(discovery)} {
	    close $socket
	    set {::sdrtcl::hl-discover-finished} 1
	} elseif {$d(discover-tries) >= $options(-discover-retries)} {
	    close $socket
	    puts "abandoning hl discovery"
	    set {::sdrtcl::hl-discover-finished} 1
	} else {
	    $self discovery send $socket
	}
    }
    method discover {} {
	$self discovery start
	vwait {::sdrtcl::hl-discover-finished}
	return $d(response)
    }
}
