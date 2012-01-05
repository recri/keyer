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
package provide sdrkit_ui 1.0.0

package require Tk
package require sdrkit

namespace eval ::sdrkit_ui {}
namespace eval ::sdrkit_ui::cmd {}

#
# common cleanup
#
proc ::sdrkit_ui::cleanup {bw w} {
    # puts "cleanup $bw $w"
    if {$bw eq $w} {
	upvar #0 $w data
	if {[info exists data(cleanup-after)]} {
	    # puts "cleanup $data(cleanup-after)"
	    after cancel $data(cleanup-after)
	}
	if {[info exists data(cleanup-func)]} {
	    foreach f $data(cleanup-func) {
		rename $f {}
	    }
	}
	unset data
    }
}

proc ::sdrkit_ui::cleanup_bind {w} {
    upvar #0 $w data
    if { ! [info exists data(cleanup-bound)]} {
	# puts "cleanup_bind $w"
	bind $w <Destroy> [list ::sdrkit_ui::cleanup %W $w]
	set data(cleanup-bound) 1
    }
}
    
proc ::sdrkit_ui::cleanup_func {w func} {
    upvar #0 $w data
    # puts "cleanup_func $w $func"
    lappend data(cleanup-func) $func
    cleanup_bind $w
}

proc ::sdrkit_ui::cleanup_after {w after} {
    upvar #0 $w data
    # puts "cleanup_after $w $after"
    set data(cleanup-after) $after
    cleanup_bind $w
}

proc ::sdrkit_ui::default_window {w} {
    if { ! [winfo exists $w] } { ttk::frame $w }
}

#
# generate a binary string with $n floating point numbers
#
proc ::sdrkit_ui::make_binary {n} {
    return [binary format f* [lrepeat n 0.0]]
}

#
# constant block, specify value
#
proc ::sdrkit_ui::constant {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::constant ::sdrkit_ui::cmd::$w]
    set data(real) 1.0
    set data(imag) 0.0
    pack [ttk::entry $w.real] -side left
    pack [ttk::entry $w.imag] -side left
    pack [ttk::label $w.j -text j] -side left
    pack [ttk::button $w.set -text set -command [list ::sdrkit_ui::cmd::$w -real ${w}(real) -imag ${w}(imag)]] -side left
    return $w
}

#
# oscillator block, specify frequency
#
proc ::sdrkit_ui::oscillator {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::oscillator ::sdrkit_ui::cmd::$w]
    set data(freq) 800
    pack [ttk::label $w.freq -textvar ${w}(freq)] -side left
    pack [ttk::scale $w.scale -length 300 -from 0 -to 10000 -variable ${w}(freq) -command [list ::sdrkit_ui::oscillator_update $w]] -side left
    return $w
}

proc ::sdrkit_ui::oscillator_update {w scale} {
    upvar #0 $w data
    ::sdrkit_ui::cmd::$w -frequency $data(freq)
}

#
# mixer block, multiply inputs
#
proc ::sdrkit_ui::mixer {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::mixer ::sdrkit_ui::cmd::$w]
    return $w
}

#
# gain block: specify scale factor
#
proc ::sdrkit_ui::gain {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::gain ::sdrkit_ui::cmd::$w]
    set data(db-gain) 0.0
    pack [ttk::label $w.gain -width 5 -textvar ${w}(db-gain)] -side left
    pack [ttk::scale $w.scale -length 300 -from -1200 -to 600 -variable ${w}(raw-db-gain) -command [list ::sdrkit_ui::gain_update $w]] -side left
    return $w
}

proc ::sdrkit_ui::gain_update {w scale} {
    upvar #0 $w data
    set data(db-gain) [format %.1f [expr {$scale/10.0}]]
    set data(gain) [expr {pow(10, $data(db-gain)/10.0)}]
    ::sdrkit_ui::cmd::$w -gain $data(gain)
}

#
# biquad block, specify coefficients
# specialize into low pass, high pass, band pass, notch blocks
#
proc ::sdrkit_ui::biquad {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::biquad ::sdrkit_ui::cmd::$w]
    return $w
}

proc ::sdrkit_ui::bq_low_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::biquad ::sdrkit_ui::cmd::$w]
    return $w
}

proc ::sdrkit_ui::bq_band_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::biquad ::sdrkit_ui::cmd::$w]
    return $w
}

proc ::sdrkit_ui::bq_high_pass {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::biquad ::sdrkit_ui::cmd::$w]
    return $w
}

proc ::sdrkit_ui::bq_notch {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::biquad ::sdrkit_ui::cmd::$w]
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
#
# meter block
# well, what kind of meter?
#
proc ::sdrkit_ui::meter {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::atap ::sdrkit_ui::cmd::$w]
    return $w
}

#
# scope block
#
# a simple two channel scope
#
proc ::sdrkit_ui::scope {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::atap ::sdrkit_ui::cmd::$w]
    
    bind $w <Configure> [list ::sdrkit_ui::scope_configure %W $w %w %h]
    grid [canvas $w.c -width 400 -height 320] -row 0 -column 0 -sticky nsew
    
    grid [ttk::frame $w.f] -row 0 -column 1 -stick n
    set row -1
    # vertical controls
    pack [ttk::frame $w.v -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.v.l -text {Vertical}] -row [incr row] -column 0
    grid [ttk::label $w.v.pl -text {Position up/down}] -row [incr row] -column 0
    grid [ttk::scale $w.v.p -from -100 -to 100 -variable ${w}(voffset)] -row [incr row] -column 0 -sticky ew
    grid [ttk::label $w.v.dl -text {Sense units/div}] -row [incr row] -column 0
    grid [spinbox $w.v.d -textvariable ${w}(vdivision) -values [lreverse {
	1000 500 250
	100 50 25
	10 5 2.5
	1 0.5 0.25
	0.1 0.05 0.025
	0.01 0.005 0.0025
	0.001 0.0005 0.00025
	0.0001 0.00005 0.000025
	0.00001 0.000005 0.0000025
    }]] -row [incr row] -column 0 -sticky ew
    set data(voffset) 0
    set data(vdivision) 1
    
    # horizontal controls
    pack [ttk::frame $w.h -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.h.l -text {Horizontal}] -row [incr row] -column 0
    grid [ttk::label $w.h.pl -text {Position left/right}] -row [incr row] -column 0
    grid [ttk::scale $w.h.p -from -100 -to 100 -variable ${w}(hoffset)] -row [incr row] -column 0 -sticky ew
    grid [ttk::label $w.h.dl -text {Sweep ms/div}] -row [incr row] -column 0
    grid [spinbox $w.h.d -textvariable ${w}(hdivision) -values [lreverse {
	1000 500 250
	100 50 25
	10 5 2.5
	1 0.5 0.25
	0.1 0.05 0.025
	0.01 0.005 0.0025
	0.001 0.0005 0.00025
	0.0001 0.00005 0.000025
    }]] -row [incr row] -column 0
    set data(hoffset) 0
    set data(hdivision) 1
    
    # trigger controls
    pack [ttk::frame $w.t -border 2 -relief raised] -in $w.f -side top -fill x
    grid [ttk::label $w.t.l -text {Trigger}] -row [incr row] -column 0
    grid [ttk::menubutton $w.t.t -textvar ${w}(trigger) -menu $w.t.t.m] -row [incr row] -column 0 -sticky ew
    menu $w.t.t.m -tearoff no
    foreach t {ilevel qlevel free} {
	$w.t.t.m add radiobutton -label $t -value $t -variable ${w}(trigger)
    }
    grid [ttk::scale $w.t.tl -from -100 -to 100 -variable ${w}(trigger-level)] -row [incr row] -column 0 -sticky ew
    set data(trigger) ilevel
    set data(trigger-level) 0
    
    pack [ttk::frame $w.d -border 2 -relief raised] -in $w.f -side top -fill x -expand true
    grid [ttk::label $w.d.l -text {Display}] -row [incr row] -column 0 -sticky ew
    grid [ttk::menubutton $w.d.d -textvar ${w}(display) -menu $w.d.d.m] -row [incr row] -column 0 -sticky ew
    menu $w.d.d.m -tearoff no
    foreach d {{i and q} {i only} {q only} {i vs q}} {
	$w.d.d.m add radiobutton -label $d -value $d -variable ${w}(display)
    }
    grid [ttk::checkbutton $w.d.f -text Freeze -variable ${w}(freeze)] -row [incr row] -column 0 -sticky ew
    set data(display) {i and q}
    set data(freeze) 0
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1
    cleanup_after $w [after 500 [list ::sdrkit_ui::scope_update $w]]
    return $w
}

proc ::sdrkit_ui::scope_update {w} {
    upvar #0 $w data
    # the milliseconds displayed on screen, ms/div * 10div
    set ms_per_screen [expr {$data(hdivision)*10}]
    # the samples per millisecond, samples/sec / 1000ms/sec
    set samples_per_ms [expr {[sdrkit::jack sample-rate]/1000.0}]
    # the number of samples on screen
    set samples_per_screen [expr {$ms_per_screen * $samples_per_ms}]
    # the number of pixels per sample
    set pixels_per_sample [expr {$data(wd) / $samples_per_screen}]
    # get the current sample buffer
    set b [::sdrkit_ui::cmd::$w]
    # count the samples received
    set ns [expr {[string length $b]/8}]
    # if that isn't enough, then get more next time
    if {$ns < $samples_per_screen * 2} {
	::sdrkit_ui::cmd::$w -b [make_binary [expr {$samples_per_screen * 2}]]
    }
    # compute the number of floats to scan
    set nf [expr {int(min($ns,$samples_per_screen*2))}]
    set n [binary scan $b f$nf vals]
    if { ! $data(freeze)} {
	if {$n == 1 && [llength $vals] == $nf} {
	    set is {}
	    set qs {}
	    set t 0
	    foreach {i q} $vals {
		lappend is $t $i
		lappend qs $t $q
		incr t
	    }
	    if { ! [info exists data(itrace)]} {
		set data(itrace) [$w.c create line $is -fill blue -tags {trace itrace}]
		set data(qtrace) [$w.c create line $qs -fill red -tags {trace qtrace}]
	    } else {
		$w.c coords $data(itrace) $is
		$w.c coords $data(qtrace) $qs
	    }
	    # move y0 to center screen
	    # move trigger sample to left
	    $w.c move trace 0 $data(y0)
	    # scale according sweep rate and sensitivity
	    $w.c scale trace 0 $data(y0) $pixels_per_sample [expr {$data(yg)/$data(vdivision)}]
	    # move
	} else {
	    puts "buffer length is [string length $b]"
	    puts "binary scan tap == $n"
	    puts "llength \$vals == [llength $vals]"
	}
    }
    cleanup_after $w [after 100 [list ::sdrkit_ui::scope_update $w]]
}

proc ::sdrkit_ui::scope_configure {bw w width height} {
    upvar #0 $w data
    if {$bw eq "$w.c"} {
	set x0 [expr {$width/2.0}]
	set y0 [expr {$height/2.0}]
	set wd [expr {$width-3}]
	set ht [expr {$height-3}]
	set xg [expr {$wd/10.0}]
	set yg [expr {$ht/8.0}]
	set xmg [expr {$xg/5.0}]
	set ymg [expr {$yg/5.0}]
	if { ! [info exists data(x0)]} {
	    for {set i 0} {$i <= 10} {incr i} {
		if {$i <= 8} {
		    set y [expr {$i*$yg+1}]
		    set data(h$i) [$w.c create line 0 $y $wd $y]
		}
		set x [expr {$i*$xg+1}]
		set data(v$i) [$w.c create line $x 0 $x $ht]
	    }
	} else {
	    for {set i 0} {$i <= 10} {incr i} {
		if {$i <= 8} {
		    set y [expr {$i*$yg+1}]
		    $w.c coords $data(h$i) 0 $y $wd $y
		}
		set x [expr {$i*$xg+1}]
		$w.c coords $data(v$i) $x 0 $x $ht
	    }
	}
	array set data [list x0 $x0 y0 $y0 wd $wd ht $ht xg $xg yg $yg xmg $xmg ymg $ymg]
    }
}

#
# spectrogram block
#
proc ::sdrkit_ui::spectrogram {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::atap ::sdrkit_ui::cmd::$w]
    return $w
}

#
# waterfall block
#
proc ::sdrkit_ui::waterfall {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::atap ::sdrkit_ui::cmd::$w]
    return $w
}

#
# iq balancer block
# 1) looks at the rotation of the signal with time to determine if
# we're looking at iq or qi.  iq rotates ccw, qi rotates cw.
# 2) compares the average magnitude of i and q to see if they are
# balanced.
# 3) shifts the phase between the two to make them quadrature
# taps the result of the balance to verify magnitude
# runs real ffts on each channel to verify frequency spectrum symmetry/asymmetry
#
proc ::sdrkit_ui::iqbalance {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::atap ::sdrkit_ui::cmd::$w]
    pack [ttk::label $w.l0 -textvar ${w}(l0)] -side top 
    pack [ttk::label $w.l1 -textvar ${w}(l1)] -side top
    pack [ttk::label $w.l2 -textvar ${w}(l2)] -side top
    array set data {
	n0 0 sum0 0 sum02 0 mean0 0 var0 0 l0 {w/s: n 0 mean 0 var 0}
	n1 0 sum1 0 sum12 0 mean1 0 var1 0 l1 {i/q: n 0 mean 0 var 0}
	n2 0 sum2 0 sum22 0 mean2 0 var2 0 l2 {?/?: n 0 mean 0 var 0}
    }
    pack [canvas $w.c -width 300 -height 30] -side top -fill x
    set data(i) [$w.c create rectangle 0  0 0 10 -fill blue -outline blue -tags i]
    set data(s) [$w.c create rectangle 150 10 150 20 -fill red -outline red -tags s]
    set data(q) [$w.c create rectangle 0 20 0 30 -fill blue -outline blue -tags q]
    cleanup_after $w [after 100 [list ::sdrkit_ui::iqbalance_update $w]]
    return $w
}

proc ::sdrkit_ui::iqbalance_update {w} {
    upvar #0 $w data
    set nvals 4096
    # if the scan worked and there's a non-zero value
    set buff [::sdrkit_ui::cmd::$w]
    set scan [binary scan $buff f$nvals vals]
    if {$scan == 1 &&
	[llength $vals] == $nvals &&
	([lindex $vals 0] != 0 || [lindex $vals 1] != 0)} {
	# check rotation per sample
	foreach {i q} [lrange $vals 0 2] break
	# compute phase of first sample
	set tp [expr {atan2($q,$i)}]
	foreach {i q} [lrange $vals 2 end] {
	    # compute phase of next sample
	    set t [expr {atan2($q,$i)}]
	    # compute change of phase between samples
	    set dt [expr {$t-$tp}]
	    # avoid discontinuity at -pi +pi
	    if {$dt > 1} {
		set dt [expr {$dt-2*atan2(0,-1)}]
	    } elseif {$dt < -1} {
		set dt [expr {$dt+2*atan2(0,-1)}]
	    }
	    # accumulate mean and variance
	    set data(sum0) [expr {$data(sum0)+$dt}]
	    set data(sum02) [expr {$data(sum02)+$dt*$dt}]
	    incr data(n0)
	    # step to the next
	    set tp $t
	}
	# display rotation summary
	if {($data(n0) % 10*$nvals) == 0} {
	    set data(mean0) [expr {$data(sum0)/$data(n0)}]
	    set data(var0) [expr {$data(sum02)/$data(n0) - $data(mean0)*$data(mean0)}]
	    set data(l0) [format {w/s: n %d mean %f var %f} $data(n0) $data(mean0) $data(var0)]
	    if {$data(n0) > 1000000} {
		set data(n0) 0
		set data(sum0) 0
		set data(sum02) 0
	    }
	}
	# compute rms power over sample for each channel
	set isum2 0
	set qsum2 0
	foreach {i q} $vals {
	    set isum2 [expr {$isum2+$i*$i}]
	    set qsum2 [expr {$qsum2+$q*$q}]
	}
	set i [expr {sqrt($isum2/($nvals/2))}]
	set q [expr {sqrt($qsum2/($nvals/2))}]
	# compute ratio of rms(i) to rms(q)
	set r [expr {$i/$q}]
	incr data(n1)
	set data(sum1) [expr {$data(sum1)+$r}]
	set data(sum12) [expr {$data(sum12)+$r*$r}]
	# setup for power display
	set b [expr {150+150*($i/$q - 1)}]
	set idb [expr {10*log10($i)}]
	set qdb [expr {10*log10($q)}]
	# puts "isq $idb $sdb $qdb dB"
	$w.c coords $data(i) 0  0 [expr {300*(120+$idb)/126}] 10
	$w.c coords $data(s) $b 10 $b 20
	$w.c coords $data(q) 0 20 [expr {300*(120+$qdb)/126}] 30
	# display power summary
	if {$data(n1) > 0 && ($data(n1) % 20) == 0} {
	    set data(mean1) [expr {$data(sum1)/$data(n1)}]
	    set data(var1) [expr {$data(sum12)/$data(n1) - $data(mean1)*$data(mean1)}]
	    set data(l1) [format {i/q: n %d mean %f var %f} $data(n1) $data(mean1) $data(var1)]
	}
    }
    cleanup_after $w [after 100 [list ::sdrkit_ui::iqbalance_update $w]]
}

