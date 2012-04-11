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
package provide sdrblk::ui-band-pass 1.0.0

package require Tk
package require snit

package require sdrkit
package require sdrkit::jack
package require sdrkit::filter-overlap-save

snit::widget ::sdrblk::ui-band-pass {
    option -server default
    option -name bandpass
    option -filter-length 513
    option -filter-length-values {17 33 65 129 257 513 1025 2049 4097 8193}
    option -center 0
    option -min-center -5000
    option -max-center 5000
    option -width 8192
    option -min-width 50
    option -max-width 10000
    
    ## qtradio filter settings
    variable qtradiofilters -array {
	{cw 0} {100 1100} {cw 1} {200 1000} {cw 2} {225 975} {cw 3} {300 900} {cw 4} {350 850} 
	{cw 5} {400 800} {cw 6} {475 725} {cw 7} {550 650} {cw 8} {575 625} {cw 9} {587 613} 
	{ssb 0} {150 5150} {ssb 1} {150 4550} {ssb 2} {150 3950} {ssb 3} {150 3450} {ssb 4} {150 3050} 
	{ssb 5} {150 2850} {ssb 6} {150 2550} {ssb 7} {150 2250} {ssb 8} {150 1950} {ssb 9} {150 1150} 
	{dsb 0} {-8000 8000} {dsb 1} {-6000 6000} {dsb 2} {-5000 5000} {dsb 3} {-4000 4000} {dsb 4} {-3300 3300} 
	{dsb 5} {-2600 2600} {dsb 6} {-2000 2000} {dsb 7} {-1550 1550} {dsb 8} {-1450 1450} {dsb 9} {-1200 1200} 
    }

    method draw-filter {wd ht} {
	# get the window size, if any
	if {$wd == 0 || $ht == 0} {
	    return
	}

	# get the transformed filter coefficients
	lassign [$options(-name) get] frame filter

	# scan into list of doubles
	binary scan $filter f* filter

	# convert to magnitudes in dB and reorder into min to max frequency
	set l [llength $filter]
	puts "$l filter coefficients"
	set n [expr {$l/2}]
	set j -1
	set c [dict create]
	set d [dict create]
	lassign {1e5 -1e5} mint maxt
	lassign {0 0 0 0 0 0 0 0} t0 t1 t2 t3 t4 t5 t6 t7
	set lhs [lrange $filter $n end]
	set rhs [lrange $filter 0 [expr {$n-1}]]
	puts "lhs [llength $lhs] and rhs [llength $rhs]"
	foreach {r i} [concat $lhs $rhs] {
	    lassign [list [sdrkit::power-to-dB [expr {1e-160+$r*$r+$i*$i}]] $t0 $t1 $t2 $t3 $t4 $t5 $t6] t0 t1 t2 t3 t4 t5 t6 t7
	    dict set c [incr j] $t0
	    set mint [expr {min($mint,$t0)}]
	    set maxt [expr {max($maxt,$t0)}]
	    dict set d $j [expr {($t0+$t1+$t2+$t3+$t4+$t5+$t6+$t7)/8}];	# smoothed version
	}
	    
	# draw the dB scale
	for {set y -160} {$y < 10} {incr y 10} {
	    lappend dB 10 $y 15 $y 10 $y
	}
	
	# draw the freq scale
	set fxy {}
	set f [sdrkit::jack -server $options(-server) sample-rate]
	set minf [expr {-$f/2.0}]
	set maxf [expr {$f/2.0}]
	puts "sr $f minf $minf maxf $maxf"
	for {set fx [expr {int($minf)}]} {$fx < $maxf} {incr fx 5000} {
	    set x [expr {$l/2*($fx-$minf)/$f}]
	    lappend fxy $x -170 $x -160 $x -170
	}
	puts "max j $j max x $x"
	set df [expr {$f/$l}]
	#set f [expr {[sdrkit::jack -server $options(-server) sample-rate]/2.0}]

	# delete the old filter, if any
	if {[llength [$win.c find all]]} {
	    $win.c delete all
	}
	# draw the new filter
	#$win.c create line $d -fill white
	$win.c create line $c -fill white
	$win.c create line $dB -fill white
	$win.c create line $fxy -fill white

	# scale to fill: bounding box from 0 lowest-negative-
	# power runs from 0 .. 
	set bbox [$win.c bbox all]
	if {$bbox eq {}} return
	lassign $bbox x1 y1 x2 y2
	puts "wd $wd ht $ht bbox $x1 $y1 $x2 $y2"
	puts "$win.c scale all 0 0 [expr {double($wd)/($x2-$x1)}] [expr {double($ht)/($y2-$y1)}]"
	$win.c scale all 0 0 [expr {double($wd)/($x2-$x1)}] [expr {-double($ht)/200.0}]
	$win.c move all 0 20
	
	# add some labels
	set text [format "center %d width %d length %d max %.1f min %.1f" $options(-center) $options(-width) $options(-filter-length) $maxt $mint]
	$win.c create text 5 [expr {$ht-5}] -text $text -anchor sw -fill white

    }

    method set-filter {} {
	set lo [expr {$options(-center)-$options(-width)/2}]
	set hi [expr {$options(-center)+$options(-width)/2}]
	$options(-name) configure -low $lo -high $hi -length  $options(-filter-length)
	while {1} {
	    lassign [$options(-name) modified] frame modified
	    if { ! $modified } break
	    puts "waiting for filter config in set-filter"
	    after 2
	}
	$self draw-filter [winfo width $win.c] [winfo height $win.c]
    }

    method set-width {args} {
	# $self set-filter
    }
    method set-center {args} {
	# $self set-filter
    }
    method set-filter-length {args} {
	# $self set-filter
    }

    method window-configure {wd ht} {
	$self draw-filter $wd $ht
    }

    constructor {args} {
	$self configure {*}$args

	sdrkit::filter-overlap-save $options(-name) -server $options(-server)

	set row 0
	grid [ttk::label $win.lw -text {filter width}] -row $row -column 0
	grid [ttk::spinbox $win.width -command [mymethod set-width] -textvariable [myvar options(-width)] \
		  -from $options(-min-width) -to $options(-max-width) -increment 1 -width 5 -format %5.0f \
		 ] -row $row -column 1 -sticky ew
	incr row
	grid [ttk::label $win.lc -text {filter center}] -row $row -column 0
	grid [ttk::spinbox $win.center -command [mymethod set-center] -textvariable [myvar options(-center)] \
		  -from $options(-min-center) -to $options(-max-center) -increment 1 -width 5 -format %5.0f \
		 ] -row $row -column 1 -sticky ew
	incr row
	grid [ttk::label $win.ll -text {filter length}] -row $row -column 0
	grid [ttk::spinbox $win.length -command [mymethod set-filter-length] -textvariable [myvar options(-filter-length)] \
		  -values $options(-filter-length-values) -width 5 -format %3.0f \
		 ] -row $row -column 1 -sticky ew
	incr row
	grid [ttk::button $win.apply -text {apply} -command [mymethod set-filter]] -row $row -column 0 -columnspan 2
	incr row
	grid [canvas $win.c -bg black] -row $row -column 0 -columnspan 2 -sticky nsew
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win $row -weight 1
	$self set-filter
	bind $win.c <Configure> [mymethod window-configure %w %h]
    }

    destructor {
	catch {rename $options(-name) {}}
    }
}


