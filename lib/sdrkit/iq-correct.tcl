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
# an iq-correct component
#

package provide sdrkit::iq-correct 1.0.0

package require snit
package require sdrtcl::iq-correct
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::iq-correct {    
    option -name sdr-iq-correct
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -options {-mu}

    option -mu -default 0 -configuremethod Configure

    option -sub-controls {
	mu radio {-values {0 1} -labels {Off On} -format {Correct}}
	error button {-text Error}
	train button {-text Train}
    }

    variable data -array {
	mu 1
	wreal 0
	wimag 0
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {w} {
	sdrtcl::iq-correct ::sdrkitx::$options(-name) -server $options(-server) -mu $options(-mu)
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    switch $opt {
		error { lappend opts -command [mymethod get-error] }
		train { lappend opts -command [mymethod do-train] }
	    }
	    if {[info exists options(-$opt]} {
		$common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    } else {
		$common window $w $opt $type $opts {} {} {}
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
    method is-needed {} { return [expr {$options(-mu) != 0}] }

    method get-error {} {
	if {[sdrkitx::$options(-name) is-active]} {
	    set e [sdrkitx::$options(-name) error]
	    puts "iq-correct error $e"
	} else {
	    puts "iq-correct is not activated"
	}
    }

    # train the adaptive filter for one buffer
    # use mu and w = w0 + p * dw to get f, a new w
    # compute the x and y displacement for f-w
    # compute the magnitude of f-w
    # compute the dot product of dw and f-w
    method train {mu w0 p dw} {
	# puts "train $mu {$w0} $p {$dw}"
	lassign $w0 x0 y0
	lassign $dw dx dy
	set w [list [expr {$x0+$p*$dx}] [expr {$y0+$p*$dy}]]
	# puts "w $w"
	set f [lrange [sdrkitx::$options(-name) train $mu {*}$w] 1 2]
	# puts "f $f"
	set x [expr {[lindex $f 0]-[lindex $w 0]}]
	set y [expr {[lindex $f 1]-[lindex $w 1]}]
	set m [expr {sqrt($x*$x+$y*$y)}]
	set d [expr {($x*$dx+$y*$dy)/$m}]
	return [list $p $w $f $x $y $m $d]
    }

    method do-train {} {
	if {[sdrkitx::$options(-name) is-active]} {
	    # find the average error signal
	    lassign [sdrkitx::$options(-name) error] frame ereal eimag
	    set e [expr {max(abs($ereal),abs($eimag))}]

	    # choose mu to produce filter updates ~ 1e-10
	    set mu [expr {1e-10/$e}]

	    # evaluate the filter at w = {0 0}
	    lassign [$self train $mu {0 0} 0 {0 0}] p0 w0 f0 x0 y0 m0 d0

	    ## the direction of our line search, normalized to length 1
	    set dw [list [expr {$x0/$m0}] [expr {$y0/$m0}]]

	    ## correct direction of filter coefficients at point 0
	    set d0 1
	    puts "p0 $p0 $w0 $f0 $m0 $d0"

	    # evaluate the filter at w {$dx $dy} projected to circumference of unit circle
	    lassign [$self train $mu $w0 1 $dw] p2 w2 f2 x2 y2 m2 d2
	    puts "p2 $p2 $w2 $f2 $m2 $d2"
	    
	    # binary search
	    for {set try 0} {$try < 24} {incr try} {
		lassign [$self train $mu $w0 [expr {($p0+$p2)/2.0}] $dw] p1 w1 f1 x1 y1 m1 d1
		puts "p1 $p1 $w1 $f1 $m1 $d1"
		if {$m1 < 1e-10} {
		    # call it quits
		    break
		} elseif {$d0 > 0 && $d1 < 0} {
		    # move search to p0 .. p1
		    lassign [list $p1 $w1 $f1 $x1 $y1 $m1 $d1] p2 w2 f2 x2 y2 m2 d2
		} elseif {$d1 > 0 && $d2 < 0} {
		    # move search to p1 .. p2
		    lassign [list $p1 $w1 $f1 $x1 $y1 $m1 $d1] p0 w0 f0 x0 y0 m0 d0
		} elseif {$d1 == 0} {
		    # unlikely, but possible
		    break
		}
	    }
	    puts "w = $w1, f = $f1, m = $m1, d = $d1"
	    sdrkitx::$options(-name) set $mu {*}$w1
	} else {
	    puts "iq-correct is not activated"
	}
    }
}
