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
package provide wrap::biquad 1.0.0
package require wrap
package require sdrtcl::biquad
namespace eval ::wrap {}
#
# biquad block, specify coefficients
# specialize into low pass, high pass, band pass, notch blocks
#
proc ::wrap::biquad {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::biquad ::wrap::cmd::$w]
    return $w
}

proc ::wrap::bq_low_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::biquad ::wrap::cmd::$w]
    return $w
}

proc ::wrap::bq_band_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::biquad ::wrap::cmd::$w]
    return $w
}

proc ::wrap::bq_high_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::biquad ::wrap::cmd::$w]
    return $w
}

proc ::wrap::bq_notch {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::biquad ::wrap::cmd::$w]
    return $w
}

if {0} {
    #
    # this code generates a0, a1, a2, b1, and b2 coefficients for a biquad
    # filter, unfortunately, my filter wants a1, a2, b0, b1, and b2
    # faust code for the biquad
    # process(x) = vgroup("raw biquad",
    #		    x,
    #		    hslider("a0", 1, -2, 2, 0.01),
    #		    hslider("a1", 1, -2, 2, 0.01),
    #		    hslider("a2", 1, -2, 2, 0.01),
    #		    hslider("b1", 1, -2, 2, 0.01),
    #		    hslider("b2", 1, -2, 2, 0.01)) : biquad with {
    #  biquad(x,a0,a1,a2,b1,b2) = x : conv3(a0, a1, a2) : + ~ conv2(b1, b2);
    #  conv2(c0,c1,x) = c0*x+c1*x';
    #  conv3(c0,c1,c2,x) = c0*x+c1*x'+c2*x'';
    #};

    proc ::raw::biquad::ui {w} {
	package require ::faust::dsp::raw_biquad
	set bq ${w}_bq
	::faust::dsp::raw_biquad $bq
	frame $w
	::faust::ui-load $bq
	pack [::faust::dsp::raw_biquad::ui $w.faust $bq] -side top -fill x -expand true
	# initialize variables
	uplevel #0 [list set $w.filter_value [lindex [::raw::biquad::filters] 0]]
	uplevel #0 [list set $w.filter_freq 220.0]
	uplevel #0 [list set $w.filter_q 0.75]
	uplevel #0 [list set $w.filter_gain 1.00]
	pack [::ttk::menubutton $w.filter -textvar $w.filter_value -menu $w.filter.m] -side top
	menu $w.filter.m -tearoff no
	foreach f [::raw::biquad::filters] {
	    $w.filter.m add radiobutton -label $f -variable $w.filter_value -command [list ::raw::biquad::update $w]
	}
	pack [::ttk::labelframe $w.freq -text Frequency] -side top -fill x -expand true
	pack [::ttk::label $w.freq.l -width 10] -side left
	pack [::ttk::scale $w.freq.s -orient horizontal -from 10 -to 10000 -variable $w.filter_freq] -side left -fill x -expand true
	$w.freq.s configure -command [list ::raw::biquad::scale-format $w $w.freq.l %10.2f]
	$w.freq.s set [uplevel #0 [list set $w.filter_freq]]
	pack [::ttk::labelframe $w.q -text Q] -side top -fill x -expand true
	pack [::ttk::label $w.q.l -width 10] -side left
	pack [::ttk::scale $w.q.s -orient horizontal -from 0 -to 10 -variable $w.filter_q] -fill x -expand true
	$w.q.s configure -command [list ::raw::biquad::scale-format $w $w.q.l %10.7f]
	$w.q.s set [uplevel #0 [list set $w.filter_q]]
	pack [::ttk::labelframe $w.gain -text Gain] -side top -fill x -expand true
	pack [::ttk::label $w.gain.l -width 10] -side left
	pack [::ttk::scale $w.gain.s -orient horizontal -from 0 -to 2 -variable $w.filter_gain] -fill x -expand true
	$w.gain.s configure -command [list ::raw::biquad::scale-format $w $w.gain.l %10.8f]
	$w.gain.s set [uplevel #0 [list set $w.filter_gain]]
	return $w
    }
    
    proc ::raw::biquad::scale-format {w label format val} {
	$label configure -text [format $format $val]
	::raw::biquad::update $w
    }
    proc ::raw::biquad::update {w} {
	upvar #0 $w.filter_value filter $w.filter_freq freq $w.filter_q q $w.filter_gain gain
	puts "raw::biquad::update $w $filter $freq $q $gain -> [::raw::biquad $filter $freq $q $gain]"
    }
    proc ::raw::biquad {filter f0 Q {dBgain 0} {SR 44100}} {
	set filters [::raw::biquad::filters]
	if {$filter ni $filters} { error "$filter is not in {[raw-biquad-filters]}" }
	## compute rbj coefficients
	set rbjcoeff [::raw::biquad::filtercoeff $filter $f0 $Q $dBgain $SR]
	## convert rbj coefficients to biquad coefficients
	foreach {a0 a1 a2 b0 b1 b2} $rbjcoeff break
	return [list [expr {$b0/$a0}] [expr {$b1/$a0}] [expr {$b2/$a0}] [expr {-$a1/$a0}] [expr {-$a2/$a0}]]
    }
    proc ::raw::biquad::filters {} {
	return {LPF HPF BPF notch APF peakingEQ peakNotch lowShelf highShelf resonator}
    }
    proc ::raw::biquad::filtercoeff {filter f0 Q dBgain SR} {
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
	    LPF {
		return [list \
			    [expr {(1 - cos($w0))/2}] \
			    [expr { 1 - cos($w0)}] \
			    [expr {(1 - cos($w0))/2}] \
			    [expr { 1 + $alpha}] \
			    [expr {-2*cos($w0)}] \
			    [expr { 1 - $alpha}]]
	    }
	    HPF {
		return [list \
			    [expr { (1 + cos($w0))/2}] \
			    [expr {-(1 + cos($w0))}] \
			    [expr { (1 + cos($w0))/2}] \
			    [expr { 1 + $alpha}] \
			    [expr {-2*cos($w0)}] \
			    [expr { 1 - $alpha}]]
	    }
	    BPF {
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
	    APF {
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
		error "unknown filter name '$filter' in ::raw-biquad"
	    }
	}
    }
}
