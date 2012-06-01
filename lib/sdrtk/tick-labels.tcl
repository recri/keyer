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

package provide sdrtk::tick-labels 1.0.0

package require snit

## This is a conversion of the R implementation of
## the Extended-Wilkinson algorithm from https://r-forge.r-project.org/R/?group_id=872
##
#' Implements a number of axis labeling schemes, including those 
#' compared in An Extension of Wilkinson's Algorithm for Positioning Tick Labels on Axes
#' by Talbot, Lin, and Hanrahan, InfoVis 2010.
#'
#' @name labeling-package
#' @aliases labeling
#' @docType package
#' @title Axis labeling
#' @author Justin Talbot \email{jtalbot@@stanford.edu}
#' @references
#' Heckbert, P. S. (1990) Nice numbers for graph labels, Graphics Gems I, Academic Press Professional, Inc.
#' Wilkinson, L. (2005) The Grammar of Graphics, Springer-Verlag New York, Inc.
#' Talbot, J., Lin, S., Hanrahan, P. (2010) An Extension of Wilkinson's Algorithm for Positioning Tick Labels on Axes, InfoVis 2010.

namespace eval sdrtk::tick-labels {
    array set data { eps 1.11e-16 }
}

snit::type sdrtk::tick-labels {

    proc dot {v1 v2} {
	set dot 0
	foreach e1 $v1 e2 $v2 {
	    set dot [expr {$dot+$e1*$e2}]
	}
	return $dot
    }

    proc simplicity {q Q j lmin lmax lstep} {
	set eps [expr {${::sdrtk::tick-labels::data(eps)} * 100}]
	set n [llength $Q]
	set i [expr {[lsearch $Q $q]+1}]
	set v [expr {(fmod($lmin,$lstep) < $eps || $lstep - fmod($lmin, $lstep) < $eps) && $lmin <= 0 && $lmax >= 0}]
	return [expr {1 - double($i-1)/($n-1) - $j + $v}]
    }

    proc simplicity-max {q Q j} {
	set n [llength $Q]
	set i [expr {[lsearch $Q $q]+1}]
	set v 1
	return [expr {1 - double($i-1)/($n-1) - $j + $v}]
    }

    proc coverage {dmin dmax lmin lmax} {
	set range [expr {$dmax-$dmin}]
	return [expr {1 - 0.5 * (($dmax-$lmax)**2+($dmin-$lmin)**2) / ((0.1*$range)**2)}]
    }

    proc coverage-max {dmin dmax span} {
	set range [expr {$dmax-$dmin}]
	if {$span > $range} {
	    set half [expr {($span-$range)/2.0}]
	    return [expr {1 - 0.5 * ($half**2 + $half**2) / ((0.1 * $range)**2)}]
	} else {
	    return 1
	}
    }

    proc density {k m dmin dmax lmin lmax} {
	set r [expr {($k-1) / ($lmax-$lmin)}]
	set rt [expr {($m-1) / (max($lmax,$dmax)-min($dmin,$lmin))}]
	return [expr {2 - max( $r/$rt, $rt/$r )}]
    }

    proc density-max {k m} {
	if {$k >= $m} {
	    return [expr {2 - double($k-1)/($m-1)}]
	} else {
	    return 1
	}
    }

    proc legibility {lmin lmax lstep} {
	return 1;			## did all the legibility tests in C#, not in R.
    }

    proc seq-n {min max n} {
	if {$min == $max} {
	    set min [expr {$min-0.1}]
	    set max [expr {$min+0.1}]
	}
	return [seq-step $min $max [expr {($max-$min)/($n-1)}]]
    }

    proc seq-step {min max step} {
	if {$min == $max} {
	    set min [expr {$min-0.1}]
	    set max [expr {$min+0.1}]
	}
	if {$step == 0} {
	    set step [expr {($max-$min)/2.0}]
	}
	set seq {}
	for {set x $min} {$x <= $max} {set x [expr {$x+$step}]} {
	    lappend seq $x
	}
	return $seq
    }

    #' An Extension of Wilkinson's Algorithm for Position Tick Labels on Axes
    #'
    #' \code{extended} is an enhanced version of Wilkinson's optimization-based axis labeling approach. It is described in detail in our paper. See the references.
    #' 
    #' @param dmin minimum of the data range
    #' @param dmax maximum of the data range
    #' @param m number of axis labels
    #' @param Q set of nice numbers
    #' @param only.loose if true, the extreme labels will be outside the data range
    #' @param w weights applied to the four optimization components (simplicity, coverage, density, and legibility)
    #' @return vector of axis label locations
    #' @references
    #' Talbot, J., Lin, S., Hanrahan, P. (2010) An Extension of Wilkinson's Algorithm for Positioning Tick Labels on Axes, InfoVis 2010.
    #' @author Justin Talbot \email{jtalbot@@stanford.edu}
    #' @export
    method extended {dmin dmax m {Q {1 5 2 2.5 4 3}} {only_loose false} {w {0.25 0.2 0.5 0.05}}} {
	set eps [expr {${::sdrtk::tick-labels::data(eps)} * 100}]

	if {$dmin > $dmax} {
	    lassign [list $dmin $dmax] dmax dmin
	    # puts "reversed order of $dmin $dmax"
	}
	
	if {$dmax - $dmin < $eps} {
	    #if the range is near the floating point limit,
	    #let seq generate some equally spaced steps.
	    # puts "range is less than $eps"
	    return [seq-n $dmin $dmax $m]
	}
	set n [llength $Q]
	
	set best {}
	set best_score -2
	
	for {set j 1} {$j < Inf} {set j [expr {$j+1}]} {
	    # puts "iteration j = $j"
	    foreach q $Q {
		# puts "iteration q = $q"
		set sm [simplicity-max $q $Q $j]
		if {[dot $w [list $sm 1 1 1]] < $best_score} {
		    set j Inf
		    # puts "set j Inf -> $j and break"
		    break
		}
		for {set k 2} {$k < Inf} {incr k} {
		    # puts "iteration k $k"
		    set dm [density-max $k $m]

		    if {[dot $w [list $sm 1 $dm 1]] < $best_score} break

		    set delta [expr {double($dmax-$dmin)/($k+1)/$j/$q}]
		    for {set z [expr {ceil(log10($delta))}]} {$z < Inf} {set z [expr {$z+1}]} {
			#puts "iteration z $z"
			set step [expr {$j*$q*10**$z}]
			#puts "step $step"
			set cm [coverage-max $dmin $dmax [expr {$step*($k-1)}]]
			#puts "coverage-max $cm"
			if {[dot $w [list $sm $cm $dm 1]] < $best_score} break
			
			set min_start [expr {floor($dmax/($step))*$j - ($k - 1)*$j}]
			set max_start [expr {ceil($dmin/($step))*$j}]
			#puts "min_start $min_start maxstart $max_start"
			if {$min_start > $max_start} continue

			foreach start [seq-step $min_start $max_start 1] {
			    #puts "iteration start $start"
			    set lmin [expr {$start * ($step/$j)}]
			    set lmax [expr {$lmin + $step*($k-1)}]
			    set lstep $step

			    set s [simplicity $q $Q $j $lmin $lmax $lstep]
			    set c [coverage $dmin $dmax $lmin $lmax]						
			    set g [density $k $m $dmin $dmax $lmin $lmax]
			    set l [legibility $lmin $lmax $lstep]						
			    
			    set score [dot $w [list $s $c $g $l]]

			    if {$score > $best_score && (!$only_loose || ($lmin <= $dmin && $lmax >= $dmax))} {
				set best_score $score
				set best [list $lmin $lmax $lstep]
			    }
			}
		    }				
		}
	    }
	}
	return [seq-step {*}$best]
    }
}