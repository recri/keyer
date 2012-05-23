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
## ui-bandpass - band pass filter controller
##
## this should build filters and preview them without
## needing an overlap save instance, just construct
## FIR kernels to spec and fftw them.
##
## it should be no problem to convolve a bandpass with
## a bandstop or two to notch something out.
##
package provide sdrui::band-pass 1.0.0

package require Tk
package require snit

package require sdrtcl
package require sdrtcl::jack
package require sdrtcl::filter-overlap-save

package require sdrtcl::filter-fir
package require sdrtcl::window
package require sdrtcl::fftw

package require sdrtk::radiomenubutton

snit::widget sdrui::band-pass {
    option -server default
    option -name bandpass
    option -filter-length 513
    option -min-filter-length 17
    option -max-filter-length 8193
    option -center 0
    option -min-center -5000
    option -max-center 5000
    option -cutoff 4096
    option -min-cutoff -24000
    option -max-cutoff -24000
    option -width 8192
    option -min-width 50
    option -max-width 10000
    option -sample-rate 96000
    
    ## qtradio filter settings
    variable qtradiofilters -array {
	{cw 0} {100 1100} {cw 1} {200 1000} {cw 2} {225 975} {cw 3} {300 900} {cw 4} {350 850} 
	{cw 5} {400 800} {cw 6} {475 725} {cw 7} {550 650} {cw 8} {575 625} {cw 9} {587 613} 
	{ssb 0} {150 5150} {ssb 1} {150 4550} {ssb 2} {150 3950} {ssb 3} {150 3450} {ssb 4} {150 3050} 
	{ssb 5} {150 2850} {ssb 6} {150 2550} {ssb 7} {150 2250} {ssb 8} {150 1950} {ssb 9} {150 1150} 
	{dsb 0} {-8000 8000} {dsb 1} {-6000 6000} {dsb 2} {-5000 5000} {dsb 3} {-4000 4000} {dsb 4} {-3300 3300} 
	{dsb 5} {-2600 2600} {dsb 6} {-2000 2000} {dsb 7} {-1550 1550} {dsb 8} {-1450 1450} {dsb 9} {-1200 1200} 
    }

    variable data -array {
	old-filter-length 0
	fftw ::sdrui::band-pass-fftw
	coeffs {}
	filter {}
	busy 0
	filter-type {bandpass}
    }

    method draw-filter {wd ht} {
	# get the window size, if any
	if {$wd == 0 || $ht == 0} {
	    return
	}

	# get the transformed filter coefficients
	set filter $data(filter)

	# scan into list of doubles
	binary scan $filter f* filter

	# reorder by frequency from min to max
	set l [llength $filter]
	set n [expr {$l/2}]
	set filter [concat [lrange $filter $n end] [lrange $filter 0 [expr {$n-1}]]]

	# set up the frequency scale
	set sr $options(-sample-rate)
	set df [expr {double($sr)/$n}]
	set minf [expr {-$df*$n/2}]
	set maxf [expr {$df*($n/2-1)}]
	set f $minf
		
	# convert to magnitudes in dB, negated
	set c [dict create]
	foreach {r i} $filter {
	    set p [sdrtcl::power-to-dB [expr {1e-16+$r*$r+$i*$i}]]
	    dict set c $f [expr {-$p}]
	    set f [expr {$f+$df}]
	}
	    
	# delete the old filter, if any
	if {[llength [$win.ui.c find all]]} {
	    $win.ui.c delete all
	}

	# draw the new filter
	$win.ui.c create line $c -fill white

	# frame it
	lassign [$win.ui.c bbox all] x1 y1 x2 y2
	#puts "raw bounding box $x1 $y1 $x2 $y2"
	set y1 [expr {-20}]
	set y2 [expr {160}]
	#puts "rounded raw bounding box $x1 $y1 $x2 $y2"
	$win.ui.c create rectangle $x1 $y1 $x2 $y2 -outline grey -fill {}

	# draw the dB scale
	set dt [expr {($x2-$x1)*0.01}]
	set x1dt [expr {$x1-$dt}]
	set x2dt [expr {$x2+$dt}]
	foreach y {0 20 40 60 80 100 120 140 160} {
	    if {$y > $y1 && $y < $y2} {
		$win.ui.c create line $x1 $y $x1dt $y -fill white
		$win.ui.c create text $x1dt $y -anchor e -text "-$y " -fill white
		$win.ui.c create line $x2 $y $x2dt $y -fill white 
		$win.ui.c create text $x2dt $y -anchor w -text " -$y" -fill white
	    }
	}
	
	# draw the freq scale
	set dt [expr {($y2-$y1)*0.01}]
	set y1dt [expr {$y1-$dt}]
	set y2dt [expr {$y2+$dt}]
	set y1dt2 [expr {$y1-2*$dt}]
	set y2dt2 [expr {$y2+2*$dt}]
	for {set f 0} {$f < $maxf} {incr f 1000} {
	    set bigtick [expr {($f % 10000) == 0}]
	    if {$f > $x1 && $f < $x2} {
		$win.ui.c create line $f $y1 $f [expr {$bigtick ? $y1dt2 : $y1dt}] -fill white
		$win.ui.c create line $f $y2 $f [expr {$bigtick ? $y2dt2 : $y2dt}] -fill white
		if {($f % 20000) == 0} {
		    $win.ui.c create text $f $y2dt -anchor n -text $f -fill white
		}
	    }
	    set f [expr {-$f}]
	    if {$f > $x1 && $f < $x2} {
		$win.ui.c create line $f $y1 $f [expr {$bigtick ? $y1dt2 : $y1dt}] -fill white
		$win.ui.c create line $f $y2 $f [expr {$bigtick ? $y2dt2 : $y2dt}] -fill white
		if {($f % 20000) == 0} {
		    $win.ui.c create text $f $y2dt -anchor n -text $f -fill white
		}
	    }
	    set f [expr {-$f}]
	}

	# scale to fill
	lassign [$win.ui.c bbox all] x1 y1 x2 y2
	#puts "framed bounding box $x1 $y1 $x2 $y2"
	set xs [expr {0.8*double($wd)/($x2-$x1)}]
	set ys [expr {0.8*double($ht)/($y2-$y1)}]
	$win.ui.c scale all 0 0 $xs $ys
	lassign [$win.ui.c bbox all] x1 y1 x2 y2
	#puts "scaled bounding box $x1 $y1 $x2 $y2"
	set xo [expr {($wd-($x1+$x2))/2}]
	set yo [expr {($ht-($y1+$y2))/2}]
	$win.ui.c move all $xo $yo
	lassign [$win.ui.c bbox all] x1 y1 x2 y2
	#puts "offset bounding box $x1 $y1 $x2 $y2"

	# add a title
	switch $data(filter-type) {
	    bandpass - notch {
		set text [format "$data(filter-type) center %d width %d length %d" $options(-center) $options(-width) $options(-filter-length)]
	    }
	    lowpass - highpass {
		set text [format "$data(filter-type) cutoff %d length %d" $options(-cutoff) $options(-filter-length)]
	    }
	}
	$win.ui.c create text [expr {$wd/2}] 5 -text $text -anchor n -fill white
    }

    method set-filter {} {
	if {$data(busy)} return
	set data(busy) 1
	switch $data(filter-type) {
	    bandpass - notch {
		# compute the filter points
		set lo [expr {$options(-center)-$options(-width)/2}]
		set hi [expr {$options(-center)+$options(-width)/2}]
		# build the FIR
		# usage: sdrtcl::filter-fir coeff-type filter-type sample-rate size ...
		# complex|real bandpass|bandstop|lowpass|highpass|hilbert rate n-coefficients 
		if {$data(filter-type) eq {bandpass}} {
		    binary scan [sdrtcl::filter-fir complex bandpass $options(-sample-rate) $options(-filter-length) $lo $hi] f* data(coeffs)
		} else {
		    binary scan [sdrtcl::filter-fir complex bandstop $options(-sample-rate) $options(-filter-length) $lo $hi] f* data(coeffs)
		}
	    }
	    lowpass - highpass {
		if {$data(filter-type) eq {lowpass}} {
		    binary scan [sdrtcl::filter-fir complex lowpass $options(-sample-rate) $options(-filter-length) $options(-cutoff)] f* data(coeffs)
		} else {
		    binary scan [sdrtcl::filter-fir complex highpass $options(-sample-rate) $options(-filter-length)  $options(-cutoff)] f* data(coeffs)
		}
	    }
	}
	# pad with zeroes on the left to make fft fodder
	set data(coeffs) [binary format f* [concat [lrepeat [expr {($options(-filter-length)-2)*2}] 0.0] $data(coeffs)]]
	# rebuild the fft if it's not the right size
	if {$data(old-filter-length) != $options(-filter-length)} {
	    catch {rename $data(fftw) {}}
	    sdrtcl::fftw $data(fftw) -size [expr {2*$options(-filter-length)-2}] -direction -1
	    set data(old-filter-length) $options(-filter-length)
	}
	# run the fft
	set data(filter) [$data(fftw) exec $data(coeffs)]
	# draw the result
	$self draw-filter [winfo width $win.ui.c] [winfo height $win.ui.c]
	set data(busy) 0
    }

    method old-set-filter {} {
	# don't set it if it's still digesting the last set
	# we could get here from a later ui event
	# while still waiting for the previous event to complete
	if {[$options(-name) is-busy]} return
	# set the filter points
	set lo [expr {$options(-center)-$options(-width)/2}]
	set hi [expr {$options(-center)+$options(-width)/2}]
	$options(-name) configure -low $lo -high $hi -length  $options(-filter-length)
	# wait for the setting to take effect
	while {[$options(-name) is-busy]} {
	    #puts "waiting for filter config in set-filter"
	    after 2
	}
	# get the new filter
	lassign [$options(-name) get] frame data(filter)
	# get the sample rate
	set options(-sample-rate) [sdrtcl::jack -server $options(-server) sample-rate]
	# draw the new filter
	$self draw-filter [winfo width $win.ui.c] [winfo height $win.ui.c]
    }

    method set-width {width} {
	set options(-width) [expr {int($width)}]
	$self set-filter
    }
    method set-center {center} {
	set options(-center) [expr {int($center)}]
	$self set-filter
    }
    method set-cutoff {cutoff} {
	set options(-cutoff) [expr {int($cutoff)}]
	$self set-filter
    }
    method set-filter-length {length} {
	set options(-filter-length) [expr {(int($length)&~1)+1}]; # make it odd
	#$self set-filter
    }

    method window-configure {wd ht} {
	$self draw-filter [winfo width $win.ui.c] [winfo height $win.ui.c]
    }

    method Rebuild {args} {
	catch {destroy $win.ui}
	grid [ttk::frame $win.ui] -row 0 -column 0 -sticky nsew
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win 0 -weight 1
	set row 0
	grid [sdrtk::radiomenubutton $win.ui.filter -values {lowpass highpass bandpass notch} -variable [myvar data(filter-type)] -command [mymethod Rebuild]]
	switch $data(filter-type) {
	    lowpass - highpass {
		incr row
		grid [ttk::label $win.ui.lc -text {filter cutoff}] -row $row -column 0
		grid [ttk::label $win.ui.vc -textvar [myvar options(-cutoff)] -width 5] -row $row -column 1
		set lo [expr {-$options(-sample-rate)/2}]
		set hi [expr {+$options(-sample-rate)/2}]
		grid [ttk::scale $win.ui.sc -from $lo -to $hi -variable [myvar options(-cutoff)] \
			  -command [mymethod set-cutoff]] -row $row -column 2 -sticky ew
		incr row
		grid [ttk::label $win.ui.ll -text {filter length}] -row $row -column 0
		grid [ttk::label $win.ui.vl -textvar [myvar options(-filter-length)] -width 5] -row $row -column 1
		grid [ttk::scale $win.ui.sl -from $options(-min-filter-length) -to $options(-max-filter-length) \
			  -variable [myvar options(-filter-length)] -command [mymethod set-filter-length]] -row $row -column 2 -sticky ew
		grid [ttk::button $win.ui.apply -text {apply} -command [mymethod set-filter]] -row $row -column 3
		incr row
		grid [ttk::button $win.ui.install -text {install} -command [mymethod select-filter]] -row $row -column 0 -columnspan 4
	    }
	    bandpass - notch {
		incr row
		grid [ttk::label $win.ui.lw -text {filter width}] -row $row -column 0
		grid [ttk::label $win.ui.vw -textvar [myvar options(-width)] -width 5] -row $row -column 1
		grid [ttk::scale $win.ui.sw -from $options(-min-width) -to $options(-max-width) \
			  -variable [myvar options(-width)] -command [mymethod set-width]] -row $row -column 2 -sticky ew
		incr row
		grid [ttk::label $win.ui.lc -text {filter center}] -row $row -column 0
		grid [ttk::label $win.ui.vc -textvar [myvar options(-center)] -width 5] -row $row -column 1
		set lo [expr {-$options(-sample-rate)/2}]
		set hi [expr {+$options(-sample-rate)/2}]
		grid [ttk::scale $win.ui.sc -from $lo -to $hi -variable [myvar options(-center)] -command [mymethod set-center]] -row $row -column 2 -sticky ew
		incr row
		grid [ttk::label $win.ui.ll -text {filter length}] -row $row -column 0
		grid [ttk::label $win.ui.vl -textvar [myvar options(-filter-length)] -width 5] -row $row -column 1
		grid [ttk::scale $win.ui.sl -from $options(-min-filter-length) -to $options(-max-filter-length) -variable [myvar options(-filter-length)] -command [mymethod set-filter-length]] -row $row -column 2 -sticky ew
		grid [ttk::button $win.ui.apply -text {apply} -command [mymethod set-filter]] -row $row -column 3
		incr row
		grid [ttk::button $win.ui.install -text {install} -command [mymethod select-filter]] -row $row -column 0 -columnspan 4
	    }
	    default { error "unanticipated filter type \"$data(filter-type)\"" }
	}
	incr row
	grid [canvas $win.ui.c -bg black] -row $row -column 0 -columnspan 4 -sticky nsew
	grid columnconfigure $win.ui 2 -weight 1
	grid rowconfigure $win.ui $row -weight 1
	$self set-filter
    }
    constructor {args} {
	$self configure {*}$args
	sdrtcl::filter-overlap-save $options(-name) -server $options(-server)
	$self Rebuild
	bind $win <Configure> [mymethod window-configure %w %h]
    }

    destructor {
	catch {rename $options(-name) {}}
    }
}


