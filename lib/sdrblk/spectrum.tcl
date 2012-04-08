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
# a graphical band/channel select manager
#

package provide sdrblk::spectrum 1.0

package require snit

namespace eval ::sdrblk {}

namespace eval ::sdrblk::spectrum {
    ##
    ## create the dictionary
    ##
    set spectrum [dict create]

    ##
    ## specify the spectrum ranges
    ##
    dict set spectrum ranges [dict create {*}{
	LF {30kHz 300kHz}
	MF {300kHz 3Mhz}
	HF {1.8MHz 30MHz}
	VHF {30MHz 300MHz}
	UHF {300MHz 3GHz}
	SHF {3GHz 30GHz}
	EHF {30GHz 300GHz}
    }]

    ##
    ## initialize the services
    ##
    dict set spectrum services {}

    ##
    ## convert variously formatted frequencies to Hertz
    ##
    proc hertz {string} {
	if {[regexp {^(\d+|\d+\.\d+|\.\d+|\d+\.)([eE][-+]\d+)?\s*(Hz|kHz|MHz|GHz)$} $string all number exponent unit]} {
	    set f $number$exponent
	    switch $unit {
		Hz { return [expr {$f*1.0}] }
		kHz { return [expr {$f*1000.0}] }
		MHz { return [expr {$f*1000.0*1000.0}] }
		GHz { return [expr {$f*1000.0*1000.0*1000.0}] }
	    }
	}
	error "badly formatted frequency: $string"
    }

    ##
    ## add service to spectrum database
    ##
    proc add-service {service args} {
	variable spectrum
	if {[lsearch [dict get $spectrum services] $service] >= 0} {
	    error "service \"$service\" is already defined"
	}
	foreach {name value} $args {
	    # check service values
	}
	dict lappend spectrum services $service
	dict set spectrum $service [dict create {*}$args]
	foreach item {color bands channels} default {white {} {}} {
	    if { ! [dict exists $spectrum $service $item]} {
		dict set spectrum $service $item $default
	    }
	}
    }

    ##
    ## add band to service
    ##
    proc add-band {service band args} {
	variable spectrum
	if {[lsearch [dict get $spectrum $service bands] $band] >= 0} {
	    error "band \"$band\" is already defined for service \"$service\""
	}
	foreach {name value} $args {
	    switch $name {
		low - high { hertz $value }
		name - mode - filter - channel-step {}
		default {
		    error "unknown band $name = {$value}"
		}
	    }
	}
	dict set spectrum $service bands [concat [dict get $spectrum $service bands] [list $band]]
	dict set spectrum $service $band [dict create {*}$args]
    }

    ##
    ## add channel to service
    ##
    proc add-channel {service channel args} {
	variable spectrum
	if {[lsearch [dict get $spectrum $service channels] $channel] >= 0} {
	    error "channel \"$channel\" is already defined for service \"$service\""
	}
	foreach {name value} $args {
	    switch $name {
		name - mode - filter {}
		freq { hertz $value }
		default {
		    error "unknown channel $name = {$value}"
		}
	    }
	}
	dict set spectrum $service channels [concat [dict get $spectrum $service channels] [list $channel]]
	dict set spectrum $service $channel [dict create {*}$args]
    }
    
    ##
    ## Aeronautical bands
    ##
    add-service Aeronautical color {light blue}
    foreach {low high} {
	2.850 3.155
	3.400 3.500
	4.650 4.750
	5.450 5.730
	6.525 6.765
	8.815 9.040
	10.050 10.100
	11.175 11.400
	13.200 13.360
	15.010 15.100
	17.900 18.030
	21.924 22.000
	23.200 23.350
    } {
	add-band Aeronautical $low low ${low}MHz high ${high}MHz mode SSB
    }
    add-band Aeronautical VHF low 108MHz high 137MHz mode AM
    ##
    ## Marine mobile bands
    ##
    add-service Marine color blue
    foreach {low high} {
	2.045 2.160
	2.170 2.194
	4.000 4.438
	6.200 6.525
	8.100 8.815
	12.230 13.200
	16.360 17.410
	18.780 18.900
	19.680 19.800
	22.000 22.855
	25.070 25.210
	26.100 26.175
    } {
	add-band Marine $low low ${low}MHz high ${high}MHz mode USB
    }
    # DSC 
    add-band Marine VHF low {156 MHz} high {162.025 MHz} mode NFM channel-step 25000
    add-channel Marine 9A freq {156.450 MHz} mode NFM filter {15 kHz}
    add-channel Marine 13A freq {156.650 MHz} mode NFM filter {15 kHz}
    add-channel Marine 16A freq {156.800 MHz} mode NFM filter {15 kHz}
    add-channel Marine 87B freq {161.975 MHz} mode NFM filter {15 kHz}
    add-channel Marine 88B freq {162.025 MHz} mode NFM filter {15 kHz}

    ##
    ## Broadcast radio bands
    ##
    add-service Broadcast color green
    add-band Broadcast {LW} low 148.5kHz high 283.5kHz mode AM filter 15kHz channel-step 10000
    add-band Broadcast {MW} low {520 kHz} high {1710 kHz} mode AM filter {15 kHz} channel-step 10000
    add-band Broadcast {120m} low {2300 kHz} high {2495 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {90m} low {3200 kHz} high {3400 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {75m} low {3900 kHz} high {4000 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {60m} low {4750 kHz} high {5060 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {49m} low {5900 kHz} high {6200 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {41m} low {7200 kHz} high {7450 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {31m} low {9400 kHz} high {9900 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {25m} low {11600 kHz} high {12100 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {22m} low {13570 kHz} high {13870 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {19m} low {15100 kHz} high {15800 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {16m} low {17480 kHz} high {17900 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {15m} low {18900 kHz} high {19020 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {13m} low {21450 kHz} high {21850 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {11m} low {25600 kHz} high {26100 kHz} mode AM filter {15 kHz} channel-step 5000
    add-band Broadcast {FM} low {87.5 MHz} high {108.0 MHz} mode WFM filter {50 kHz}

    ##
    ## Weather channels
    ##
    add-service Weather color grey
    add-band Weather NOAA name {NOAA Weather} low {162.400 MHz} high {162.550 MHz} mode NFM filter {50 kHz} channel-step 25000
    add-channel Weather WX1 freq 162.550MHz
    add-channel Weather WX2 freq 162.400MHz
    add-channel Weather WX3 freq 162.475MHz
    add-channel Weather WX4 freq 162.425MHz
    add-channel Weather WX5 freq 162.450MHz
    add-channel Weather WX6 freq 162.500MHz
    add-channel Weather WX7 freq 162.525MHz
    # alt {1=162.400, 2=162.425, 3=162.450, 4=162.475, 5=162.500, 6=162.525, 7=162.550 {in order of frequency channel numbering}}

    ##
    ## Amateur bands
    ##
    add-service Amateur color gold mode AM filter 2.8kHz
    add-band Amateur {136 kHz} low {135.7 kHz} high {137.8 kHz}
    add-band Amateur {160m} low {1.8 MHz} high {2 MHz}
    add-band Amateur {80m} low {3.5 MHz} high {4 MHz}
    add-band Amateur {75m} low {3.6 MHz} high {4 MHz}
    add-band Amateur {60m} low {5.2585 MHz} high {5.4035 MHz}
    add-band Amateur {40m} low {7.0 MHz} high {7.3 MHz}
    add-band Amateur {30m} low {10.1 MHz} high {10.15 MHz}
    add-band Amateur {20m} low {14 MHz} high {14.35 MHz}
    add-band Amateur {17m} low {18.068 MHz} high {18.168 MHz}
    add-band Amateur {15m} low {21 MHz} high {21.45 MHz}
    add-band Amateur {12m} low {24.89 MHz} high {25.99 MHz}
    add-band Amateur {11m} low {26 MHz} high {27 MHz}
    add-band Amateur {10m} low {28 MHz} high {29.7 MHz}
    add-band Amateur {6m} low {50 MHz} high {54 MHz} mode NFM filter {15 kHz}
    add-band Amateur {4m} low {70 MHz} high {70.5 MHz} mode NFM filter {15 kHz}
    add-band Amateur {2m} low {144 MHz} high {148 MHz} mode NFM filter {15 kHz}
    # add-band Amateur {1.25m} low {219 MHz} high {220 MHz} mode NFM filter {15 kHz}
    add-band Amateur {1.25m} low {222 MHz} high {225 MHz} mode NFM filter {15 kHz}
    add-band Amateur {70cm} low {420 MHz} high {450 MHz} mode NFM filter {15 kHz}
    add-band Amateur {33cm} low {902 MHz} high {928 MHz} mode NFM filter {15 kHz}
    add-band Amateur {23cm} low {1.24 GHz} high {1.3 GHz} mode NFM filter {15 kHz}
    add-band Amateur {13cm} low {2.3 GHz} high {2.31 GHz} mode NFM filter {15 kHz}
    add-band Amateur {9cm} low {3.3 GHz} high {3.5 GHz} mode NFM filter {15 kHz}
    add-band Amateur {5cm} low {5.65 GHz} high {5.925 GHz} mode NFM filter {15 kHz}
    add-band Amateur {3cm} low {10 GHz} high {10.5 GHz} mode NFM filter {15 kHz}
    add-band Amateur {1.2cm} low {24 GHz} high {24.25 GHz} mode NFM filter {15 kHz}
    add-band Amateur {6mm} low {47 GHz} high {47.2 GHz} mode NFM filter {15 kHz}
    add-band Amateur {4cm} low {75.5 GHz} high {81.0 GHz} mode NFM filter {15 kHz}
    add-band Amateur {2.5mm} low {119.98 GHz} high {120.02 GHz} mode NFM filter {15 kHz}
    add-band Amateur {2mm} low {142 GHz} high {149 GHz} mode NFM filter {15 kHz}
    add-band Amateur {1mm} low {241 GHz} high {250 GHz} mode NFM filter {15 kHz}


    ##
    ## WWV channels
    ##
    add-service WWV color {red}
    add-channel WWV 2.5 freq 2.5MHz mode AM
    add-channel WWV 5 freq 5MHz mode AM
    add-channel WWV 10 freq 10MHz mode AM
    add-channel WWV 15 freq 15MHz mode AM
    add-channel WWV 20 freq 20MHz mode AM
}

::snit::type ::sdrblk::spectrum {
    variable spectrum

    constructor {args} { set spectrum $::sdrblk::spectrum::spectrum }
    method get {args} { return [dict get $spectrum {*}$args] }
    method ranges {} { return [$self get ranges] }
    method range {range} { return [$self get ranges $range] }
    method range-hertz {range} { return [$self hertz {*}[$self range $range]] }
    method services {} { return [$self get services] }
    method service {service} { return [$self get $service] }
    method bands {service} { return [$self get $service bands] }
    method channels {service} { return [$self get $service channels] }
    method color {service} { return [$self get $service color] }
    method band {service band} { return [$self get $service $band] }
    method band-range {service band} { return [list [$self get $service $band low] [$self get $service $band high]] }
    method band-range-hertz {service band} { return [$self hertz {*}[$self band-range $service $band]] }
    method channel {service channel} { return [$self get $service $channel] }
    method channel-freq {service channel} { return [$self get $service $channel freq] }
    method channel-freq-hertz {service channel} { return [$self hertz [$self channel-freq $service $channel]] }
    method hertz {args} {
	switch [llength $args] {
	    0 { return {} }
	    1 { return [::sdrblk::spectrum::hertz [lindex $args 0]] }
	    default {
		set range {}
		foreach f $args { lappend range [::sdrblk::spectrum::hertz $f] }
		return $range
	    }
	}
    }
}
