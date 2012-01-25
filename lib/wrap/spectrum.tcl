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

##
## spectrum
##

package provide spectrum 1.0.0

package require Tk

namespace eval ::spectrum {
    # smooth?
    # multiple traces?
    array set default_data {
	-height 100
	-offset 0.0
	-scale 1.0
    }
}

proc ::spectrum::update {w xy} {
    upvar #0 ::spectrum::$w data
    $w coords spectrum $xy
    $w scale spectrum 0 0 $data(-scale) [expr {-[winfo height $w]/180.0}]
    $w move spectrum $data(-offset) 0
    # keep older copies fading to black
}

proc ::spectrum::configure {w args} {
    upvar #0 ::spectrum::$w data
    array set save [array get data]
    foreach {option value} $args {
	switch -- $option {
	    -scale -
	    -offset {
		set adjustpos 1
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
    if {[info exists adjustpos]} {
	$w move all [expr {-$save(-offset)}] 0
	$w scale all 0 0 [expr {$data(-scale)/$save(-scale)}] 1
	$w move all $data(-offset) 0
	# puts "spectrum::configure -scale $data(-scale) -offset $data(-offset) bbox [$w bbox all]"
    }
}

proc ::spectrum::spectrum {w args} {
    upvar #0 ::spectrum::$w data
    array set data [array get ::spectrum::default_data]
    array set data $args
    canvas $w -height $data(-height) -bg black
    $w create line 0 0 0 0 -fill white -tags spectrum
    return $w
}    

proc ::spectrum::defaults {} {
    return [array get ::spectrum::default_data]
}

proc ::spectrum {w args} {
    return [::spectrum::spectrum $w {*}$args]
}

if {0} {
    package require Tk
    package require sdrkit

    namespace eval ::spectrum {
	set n 0
    }

    proc spectrum::capture {w} {
	upvar #0 $w data
	foreach {f b} [::$data(tap) $data(n)] break
	set l [::$data(fft) $b]
	binary scan $l f* levels
    
	set report [format {%d samples %d ms %d floats} $data(n) $data(p) [llength $levels]]
	if { ! [info exists data(report)] || $data(report) ne $report} {
	    puts [set data(report) $report]
	}
	## they're ordered from 0 .. most positive, most negative .. just < 0
	## k/T, T = total sample time, n * 1/sample_rate
	set freqreport [format {max freq %.1f} [expr {($data(n)/2) / ($data(n)*(1.0/[sdrkit::jack sample-rate]))}]]
	if { ! [info exists data(freqreport)] || $data(freqreport) ne $freqreport} {
	    puts [set data(freqreport) $freqreport]
	}
	set x [expr {$data(n)/2}]
	foreach {re im} $levels {
	    lappend xy $x [expr {10*log10(($re*$re+$im*$im)+1e-16)}]
	    if {[incr x] == $data(n)} {
		set x 0
	    }
	}
	$w.c coords spectrum $xy
	set ht [winfo height $w.c]
	set wd [winfo width $w.c]
	$w.c scale spectrum 0 0 [expr {double($wd)/$x}] [expr {-double($ht)/180}]
	# $w.c move spectrum 0 [expr {$ht-10}]
	after $data(p) [list spectrum::capture $w]
    }
    
    proc spectrum {w n p} {
	upvar #0 $w data
	ttk::frame $w
	set data(n) $n
	set data(p) $p
	set data(tap) spectrum_tap_$::spectrum::n
	set data(fft) spectrum_fft_$::spectrum::n
	incr ::spectrum::n
	::sdrkit::audio-tap $data(tap) -complex 1
	::sdrkit::fftw $data(fft) $data(n)
	pack [canvas $w.c -width 512 -height 128] -side top -fill both -expand true
	$w.c create line 0 0 0 0 -tag spectrum
	spectrum::capture $w
	return $w
    }
}
