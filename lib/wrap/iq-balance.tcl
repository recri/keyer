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
package provide wrap::iq-balance 1.0.0

package require wrap::sdrkit
package require sdrtcl::iq-balance
namespace eval ::wrap {}

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
proc ::wrap::iq-balance {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrtcl::audio-tap ::wrap::cmd::$w -complex 1]
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
    cleanup_after $w [after 100 [list ::wrap::iqbalance_update $w]]
    return $w
}

proc ::wrap::iqbalance_update {w} {
    upvar #0 $w data
    set nvals 4096
    # if the scan worked and there's a non-zero value
    set buff [::wrap::cmd::$w]
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
    cleanup_after $w [after 100 [list ::wrap::iqbalance_update $w]]
}

