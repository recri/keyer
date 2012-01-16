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
package provide ::biquad-filter 1.0.0
package require sdrkit::biquad

namespace eval ::biquad-filter {
    array set default_data {
	-types {lowpass bandpass highpass allpass notch}
	-type lowpass
	-freq 750
	-q 1
	-gain 0
    }
}

proc ::biquad-filter::defaults {} {
    return [array get ::biquad-filter::default_data]
}

proc ::biquad-filter::filtercoeff {filter f0 Q dBgain SR} {
    ##----------------------------------------
    ## biquad coeffs for various filters 
    ## usage : [filtercoeff filter f0 dBgain Q]
    ##----------------------------------------
    
    ## common values
    ##	alpha 	= sin(w0)/(2*Q);
    ##	w0 		= 2*PI*f0/Fs;
    set PI [expr    {2*atan2(1,0)}]
    set w0 [expr    {2*$PI*max(0,$f0)/$SR}]
    set alpha [expr {sin($w0)/(2*max(0.001,$Q))}]
    set A  [expr    {pow(10,($dBgain/40))}];		## (for peaking and shelving EQ filters only)
    set G  [expr    {sqrt(max(0.00001, $dBgain))}];	## When gain is a linear values (i.e. not in dB)
    
    switch $filter {
	lowpass {
	    return [list \
			[expr {(1 - cos($w0))/2}] \
			[expr { 1 - cos($w0)}] \
			[expr {(1 - cos($w0))/2}] \
			[expr { 1 + $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr { 1 - $alpha}]]
	}
	highpass {
	    return [list \
			[expr { (1 + cos($w0))/2}] \
			[expr {-(1 + cos($w0))}] \
			[expr { (1 + cos($w0))/2}] \
			[expr { 1 + $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr { 1 - $alpha}]]
	}
	bandpass {
	    return [list \
			[expr {$alpha}] \
			[expr {0}] \
			[expr {-$alpha}] \
			[expr {1 + $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha}]]
	}
	notch {
	    return [list \
			[expr {1}] \
			[expr {-2*cos($w0)}] \
			[expr {1}] \
			[expr {1 + $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha}]]
	}
	allpass {
	    return [list \
			[expr {1 - $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr {1 + $alpha}] \
			[expr {1 + $alpha}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha}]]
	}
	peakingEQ {
	    return [list \
			[expr {1 + $alpha*$A}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha*$A}] \
			[expr {1 + $alpha/$A}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha/$A}]]
	}
	peakNotch {
	    return [list \
			[expr {1 + $alpha*$G}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha*$G}] \
			[expr {1 + $alpha/$G}] \
			[expr {-2*cos($w0)}] \
			[expr {1 - $alpha/$G}]]
	}
	lowShelf {
	    return [list \
			[expr {  $A*( ($A+1) - ($A-1)*cos($w0) + 2*sqrt($A)*$alpha )}] \
			[expr {2*$A*( ($A-1) - ($A+1)*cos($w0)                     )}] \
			[expr {  $A*( ($A+1) - ($A-1)*cos($w0) - 2*sqrt($A)*$alpha )}] \
			[expr {       ($A+1) + ($A-1)*cos($w0) + 2*sqrt($A)*$alpha }] \
			[expr {  -2*( ($A-1) + ($A+1)*cos($w0)                     )}] \
			[expr {       ($A+1) + ($A-1)*cos($w0) - 2*sqrt($A)*$alpha }]]
	}
	highShelf {
	    return [list \
			[expr {   $A*( ($A+1) + ($A-1)*cos($w0) + 2*sqrt($A)*$alpha )}] \
			[expr {-2*$A*( ($A-1) + ($A+1)*cos($w0)                     )}] \
			[expr {   $A*( ($A+1) + ($A-1)*cos($w0) - 2*sqrt($A)*$alpha )}] \
			[expr {        ($A+1) - ($A-1)*cos($w0) + 2*sqrt($A)*$alpha }] \
			[expr {    2*( ($A-1) - ($A+1)*cos($w0)                     )}] \
			[expr {        ($A+1) - ($A-1)*cos($w0) - 2*sqrt($A)*$alpha }]]
	}
	resonator {
	    # this one is lifted from the stk::BiQuad.setResonance() method
	    return [list \
			[expr {1}] \
			[expr {       $Q*$Q}] \
			[expr {  -2 * $Q * cos($w0)}] \
			[expr { 0.5 + $Q * cos($w0)}] \
			[expr {0}] \
			[expr {-0.5 - $Q * cos($w0)}]]
	}
	default {
	    error "unknown filter name \"$filter\""
	}
    }
}

proc ::biquad-filter::coeffs {w} {
    upvar #0 ::biquad-filter::$w data
    ## compute rbj coefficients
    ## convert rbj coefficients to biquad coefficients
    foreach {a0 a1 a2 b0 b1 b2} [::biquad-filter::filtercoeff $data(-type) $data(-f) $data(-q) $data(-gain) [sdrkit::jack sample-rate]] break
    ## return option list for filter implementation
    return [list -b0 [expr {$b0/$a0}] -b1 [expr {$b1/$a0}] -b2 [expr {$b2/$a0}] -a1 [expr {-$a1/$a0}] -a2 [expr {-$a2/$a0}]]
}

proc ::biquad-filter::configure {w args} {
    upvar #0 ::biquad-filter::$w data
    # update data
    array set data $args
    # configure the filter
    $w configure {*}[::biquad-filter::coeffs $w]
}

proc ::biquad-filter::biquad-filter {w args} {
    upvar #0 ::biquad-filter::$w data
    sdrkit::biquad $w
    ::biquad-filter::configure $w {*}[::biquad-filter::defaults]
    ::biquad-filter::configure $w {*}$args
}

proc biquad-filter {w args} {
    return [::biquad-filter::biquad-filter $w {*}$args]
}

