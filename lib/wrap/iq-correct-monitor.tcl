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
package provide iq-correct-monitor 1.0.0

package require Tk

namespace eval ::iq-correct-monitor {}

##
## meter the possible iq balancing signals
## this is plotting the transform applied
## to incoming iq signals
##
proc ::iq-correct-monitor::meter-update {w} {
    upvar #0 ::iq-correct-monitor::meter-$w data
    foreach {t wi wq ndw2 m2d2} [iq-correct get] break
    if {abs($wi) > 1e-12 && abs($wq) > 1e-12} {
	set xy {}
	foreach {t ct st} $data(theta-cos-sin) {
	    lappend xy [expr {$ct - $wi * $st}] [expr {$st - $wq * $ct}]
	}
	$w coords xyplot $xy
	$w scale xyplot 0 0 75 -75
	$w move xyplot 125 125
    }
    after 10 [list ::meters::update $w]
}

proc ::iq-correct-monitor::meter-setup {w n} {
    upvar #0 ::iq-correct-monitor::meter-$w data
    set data(n-theta) $n
    set data(theta-cos-sin) {}
    set pi [expr {atan2(0,-1)}]
    for {set i 0} {$i <= $n} {incr i} {
	set theta [expr {2*$pi*$i/$n}]
	lappend data(theta-cos-sin) $theta [expr {cos($theta)}] [expr {sin($theta)}]
    }
    catch {$w delete all}
    $w create line {0 0 0 0} -fill white -tags xyplot
}
proc ::iq-correct-monitor::meter {w args} {
    upvar #0 ::iq-correct-monitor::meter-$w data
    canvas $w -bg black -width 250 -height 250
    ::meters::setup $w 32
    return $w
}

##
## controller display for iq-correct
##
proc ::iq-correct-monitor::more-mu {w} {
    set ::data(corrector-mu) [expr {2*$::data(corrector-mu)}]
    set ::data(label-corrector-mu) [format %.13f $::data(corrector-mu)]
    iq-correct configure -mu $::data(corrector-mu)
}
proc ::iq-correct-monitor::less-mu {w} {
    set ::data(corrector-mu) [expr {$::data(corrector-mu)/2}]
    set ::data(label-corrector-mu) [format %.13f $::data(corrector-mu)]
    iq-correct configure -mu $::data(corrector-mu)
}
proc ::iq-correct-monitor::reset-ws {w} {
    iq-correct reset
}
proc ::iq-correct-monitor::ws-progress-vector {w i0 i1} {
    lassign $i0 t0 wi0 wq0 ndw20 m2dw0
    lassign $i1 t1 wi1 wq1 ndw21 m2dw1
    # construct the delta over one step
    set dt01 [expr {$t0-$t1}]
    return [list [expr {($wi0-$wi1)/$dt01}] [expr {($wq0-$wq1)/$dt01}]]
}
proc ::iq-correct-monitor::ws-reset-kick {w} {
    set ::data(n-corrector-kick) 0
    set ::data(corrector-kick) 0.0
    set ::data(label-corrector-kick) [format %.3f $::data(corrector-kick)]
}
proc ::iq-correct-monitor::ws-less-mu {w} {
    less-mu
    ws-reset-kick
}
proc ::iq-correct-monitor::ws-more-mu {w} {
    more-mu
    ws-reset-kick
}
proc ::iq-correct-monitor::update-ws {w} {
    # get the current value
    set input0 [iq-correct get]; # t wi wq ndw2 m2dw 
    # append to the list of values
    lappend ::data(corrector-input) $input0
    # extract the current values
    lassign $input0 t0 wi0 wq0 ndw20 m2dw0
    # count this step
    incr ::data(corrector-n-inputs)
    # compute the absolute and relative magnitudes of steps
    if {1} {
	set ndw [expr {sqrt($ndw20)/$::data(buffer-size)}]
	set mdw [expr {sqrt($m2dw0)/$::data(buffer-size)}]
	set mw2 [expr {$wi0*$wi0+$wq0*$wq0}]
	set mw [expr {sqrt($wi0*$wi0+$wq0*$wq0)}]
	if {$mdw != 0} {
	    set ::data(corrector-ratio) [expr {log10(1.0e-100+$ndw/$mdw)}]
	} else {
	    set ::data(corrector-ratio) 0.0
	}
	set ::data(corrector-abs-mag) [expr {log10(1.0e-100+$mdw)}]
	if {$mw2 != 0} {
	    set ::data(corrector-rel-mag) [expr {log10(1.0e-100+$mdw/$mw)}]
	} else {
	    set ::data(corrector-rel-mag) [expr {log10(1.0e-100+$mdw)}]
	}
    } else {
	set mw2 [expr {$wi0*$wi0+$wq0*$wq0}]
	set ::data(corrector-ratio) [expr {log10(1.0e-100+$ndw20/$m2dw0)}]
	set ::data(corrector-abs-mag) [expr {log10(1.0e-100+$m2dw0)}]
	if {$mw2 != 0} {
	    set ::data(corrector-rel-mag) [expr {log10(1.0e-100+$m2dw0/$mw2)}]
	} else {
	    set ::data(corrector-rel-mag) [expr {log10(1.0e-100+$m2dw0)}]
	}
    }
    # make labels
    foreach v {ratio abs-mag rel-mag} {
	set ::data(label-corrector-$v) [format %.2f $::data(corrector-$v)]
    }
    foreach v {wi wq ndw2 m2dw} {
	set ::data(corrector-$v) [expr {($::data(corrector-$v)*7+[set "${v}0"])/8.0}]
	set ::data(label-corrector-$v) [format %.10g $::data(corrector-$v)]
    }
    if {$::data(corrector-on)} {
	# enforce bounds
	if {$::data(corrector-abs-mag) > $::data(corrector-abs-mag-max)} {
	    ws-less-mu
	} elseif {$::data(corrector-rel-mag) < $::data(corrector-rel-mag-min)} {
	    ws-more-mu
	} 
	# compute progress metric
	# running average of dot products between overlapping progress vectors
	if {[llength $::data(corrector-input)] > 3} {
	    if {[catch {
		# puts "$wi $wq $ndw2 $m2dw"
		# puts "$ndw $mdw $mw"
		# update our list of filter weights
		lassign [lrange $::data(corrector-input) end-3 end-1] input3 input2 input1
		lassign [ws-progress-vector $input3 $input1] dwi31 dwq31
		lassign [ws-progress-vector $input2 $input0] dwi20 dwq20
		# normalization
		set len2 [expr {$dwi20*$dwi20+$dwq20*$dwq20}]
		# update the dot signal
		if {$len2 > 0} {
		    set newdot [expr {($dwi31*$dwi20+$dwq31*$dwq20)/$len2}]
		} else {
		    set newdot 0.0
		}
		incr ::data(n-corrector-kick)
		set ::data(corrector-kick) [expr {($::data(corrector-kick)*7+$newdot)/8.0}]
		set ::data(label-corrector-kick) [format %.3f $::data(corrector-kick)]
	    } error]} {
		puts "$error: $::errorInfo"
		if {$::data(corrector-on)} corrector-onoff
	    }
	    
	    # the problem with the kick reading is that the very next kick reading
	    # is going to share 7 readings with the previous reading
	    switch $::data(corrector-state) {
		idle {
		    ## in idle state we look for a kick of 8 to shift to converge
		    ## we need to maintain a level of mu that allows the kick to be seen
		    ## so filter coefficients cannot be frozen, then need to be turning over
		    ## this might introduce some phase noise
		    if {$::data(corrector-n-kick) > 8 && $::data(corrector-kick) > 0.75} {
			set ::data(corrector-state) converge
			ws-more-mu
		    } elseif {$::data(corrector-rel-mag) > $::data(corrector-rel-mag-max)} {
			ws-less-mu
		    }
		}
		converge {
		    ## in converge state we look a decay in the kick signal to shift to relax
		    ## mu is large, so we need to observe the level of the error signal
		    ## and adjust to keep the filter from going into oscillation or chaos
		    if {$::data(corrector-rel-mag) < $::data(corrector-rel-mag-max)} {
			set ::data(corrector-state) idle
		    } elseif {$::data(corrector-n-kick) > 8} {
			if {$::data(corrector-kick) < 0.5} {
			    ws-less-mu
			} elseif {$::data(corrector-kick) > 0.75} {
			    ws-more-mu
			}
		    }
		}
	    }
	    set ::data(label-corrector-state) $::data(corrector-state)
	    set ::data(corrector-input) [lrange $::data(corrector-input) 1 end]
	}
    }
    after 20 [list update-ws]
}
    
proc ::iq-correct-monitor::corrector-onoff {w} {
    if {$::data(corrector-on)} {
	#puts "iq-correct reset to -mu $::data(corrector-mu)"
	iq-correct reset
	iq-correct configure -mu [expr {1.0/128.0}]
    } else {
	#puts "iq-correct muted to 0"
	iq-correct configure -mu 0
	iq-correct reset
    }
}

proc ::iq-correct-monitor {w} {
    grid [ttk::label .blk$row -text {Corrector}] -row $row -column 0 -columnspan 3
    incr row
    grid [ttk::frame .blk$row] -row $row -column 0 -columnspan 3
    foreach item {mu wi wq ndw2 m2dw} {
	pack [ttk::label .blk$row.l-$item -text $item] -side left
	pack [ttk::label .blk$row.v-$item -textvariable ::data(label-corrector-$item) -width 15] -side left
	set ::data(label-corrector-$item) [format %.13f $::data(corrector-$item)]
    }
    incr row
    grid [ttk::frame .blk$row] -row $row -column 0 -columnspan 3
    foreach item {state ratio kick abs-mag rel-mag} {
	pack [ttk::label .blk$row.l-$item -text $item] -side left
	pack [ttk::label .blk$row.v-$item -textvariable ::data(label-corrector-$item) -width 10] -side left
	if {$item eq {state}} {
	    set ::data(label-corrector-$item) $::data(corrector-$item)
	} else {
	    set ::data(label-corrector-$item) [format %.2f $::data(corrector-$item)]
	}
    }
    incr row
    grid [ttk::frame .blk$row] -row $row -column 0 -columnspan 3
    pack [ttk::checkbutton .blk$row.onoff -text {Enable} -variable ::data(corrector-on) -onvalue 1 -offvalue 0 -command corrector-onoff] -side left
    pack [ttk::button .blk$row.more-mu -text {Less mu} -command [list less-mu]] -side left
    pack [ttk::button .blk$row.less-mu -text {More mu} -command [list more-mu]] -side left
    pack [ttk::button .blk$row.reset-ws -text {Reset wi/wq} -command [list reset-ws]] -side left
    incr row
    
    set row $startrow
    grid [meters .blk2$row] -row $row -column 3 -columnspan 3 -rowspan 10
    ::meters::update .blk2$row
    grid columnconfigure . 2 -weight 100
    grid columnconfigure . 5 -weight 100
    grid rowconfigure . 0 -weight 100
}
