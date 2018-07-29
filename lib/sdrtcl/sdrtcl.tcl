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

package require snit

package provide sdrtcl 1.0.0

namespace eval ::sdrtcl {}

#
# compute the power of 2 size larger than or equal to n
#
proc sdrtcl::log2-size {n} {
    return [expr {round(0.5+log($n)/log(2))}]
}

#
# convert decibels to linear, voltage
# so if full scale sine signal clips at 1.0 peak,
# then rms is 0.775, corresponding to -2.2 dB
#
proc sdrtcl::dB-to-linear {dB} {
    return [expr {pow(10,$dB/20.0)}]
}

proc sdrtcl::linear-to-dB {l} {
    return [expr {20*log10($l)}]
}

#
# convert decibels to linear, power
#
proc sdrtcl::dB-to-power {dB} {
    return [expr {pow(10,$dB/10.0)}]
}

proc sdrtcl::power-to-dB {p} {
    return [expr {10*log10($p)}]
}

#
# convert radians to degrees
#
set sdrtcl::pi [expr {atan2(-1,0)}]
set sdrtcl::two_pi [expr {2*$::sdrtcl::pi}]
set sdrtcl::half_pi [expr {$::sdrtcl::pi/2}]

proc sdrtcl::radians {degrees} {
    return [expr {$::sdrtcl::two_pi*$degrees/360.0}]
}

proc sdrtcl::degrees {radians} {
    return [expr {360.0*$radians/$::sdrtcl::two_pi}]
}

#
# s meter equivalents
#
set sdrtcl::smeter {
    {{S reading} {uV into 50ohm} dBm {dB above 1uV}}
    {S9+10dB	160.0		-63	44}
    {S9		50.2		-73	34}
    {S8		25.1		-79	28}
    {S7		12.6		-85	22}
    {S6		6.3		-91	16}
    {S5		3.2		-97	10}
    {S4		1.6		-103	4}
    {S3		0.8		-109	-2}
    {S2		0.4		-115	-8}
    {S1		0.2		-121	-14}
}

#
# a snit type that acts like an sdrtcl extension type
# or at least like some of them
#
snit::type sdrtcl::sdrtcl {
    pragma -hastypeinfo    no 
    # options
    # supplies the info dictionary
    option -info -default {}

    # common sdrtcl options
    option -verbose -default 0;	#
    # common options for jack, um, all sdrtcl framework commands have -server and -client
    # they may omit the code for port handling
    option -server -default {};	# jack specific, create only
    option -client -default {}; # jack specific, create only
    # common jack midi options
    # option -chan -default 1;	# jack midi specific
    # option -note -default 0;	# jack midi specific

    # methods
    # configure handled by snit
    # cget handled by snit
    method cset {opt value} { $self configure $opt $value }
    # info extends base
    #var info [dict create command {} option [dict create] method [dict create]]
    method {info type} {} { return [$type info type] }
    method {info options} {} { return [$type info options] }
    method {info methods} {} { return [$type info methods] }
    method {info type} {} { return [$type info type] }
    method {info command} {} { return [dict get $options(-info) command] }
    method {info option} {opt} { return [dict get $options(-info) option $opt] }
    method {info method} {met} { return [dict get $options(-info) method $met] }
    # method {info ports} {} { return [dict get $info ports] }; # jack specific
    #
}
