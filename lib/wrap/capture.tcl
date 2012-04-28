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
## capture
## provide shared capture of audio or midi signals
##

package provide capture 1.0.0

package require sdrkit
package require sdrtcl::audio-tap
package require sdrtcl::midi-tap
package require sdrtcl::fftw
package require sdrtcl::window
package require sdrtcl::window-polyphase
package require sdrtcl::jack

namespace eval ::capture {
    set ntap 0
    array set default_data {
	-connect {}
	-period 50
	-size 4096
	-polyphase 0
    }
}

proc ::capture::log2-size {n} {
    #puts "::capture::log2-size $n -> max([::sdrtcl::log2-size $n],[::sdrtcl::log2-size [::sdrtcl::jack buffer-size]])"
    return [expr {max([::sdrtcl::log2-size $n],[::sdrtcl::log2-size [::sdrtcl::jack buffer-size]])}]
}

proc ::capture::configure {w args} {
    upvar #0 ::capture::$w data
    #puts "::capture::configure $w {$args} with data {[array get data]}"
    #puts "$w state  [::capture::state $w]"
    foreach {option value} $args {
	switch -- $option {
	    -size {
		if {$data(type) eq {iq} && [info exists data(tap)]} {
		    set log2size [::capture::log2-size $value]
		    if {[$data(tap) cget -log2size] < $log2size} {
			$data(tap) configure -log2size $log2size
		    }
		}
		set data($option) $value
	    }
	    -polyphase {
		set data($option) $value
	    }
	    -period {
		set data($option) $value
	    }
	    -connect {
		switch $data(type) {
		    midi {
			foreach x $value {
			    catch {sdrtcl::jack connect $x $data(tap):midi_in}
			}
		    }
		    iq - spectrum {
			foreach x $value {
			    catch {sdrtcl::jack connect $x:out_i $data(tap):in_i}
			    catch {sdrtcl::jack connect $x:out_q $data(tap):in_q}
			}
		    }
		}
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
}

proc ::capture::capture-spectrum {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# cache a number
	set n $data(-size)
	# make sure the fft is configured
	if {[$data(fft) cget -size] != $data(-size)} {
	    $data(fft) configure -size $data(-size)
	}
	# make sure the window is configured,
	# and find out how many samples we need
	if {$data(-polyphase)} {
	    set ns [expr {$data(-size)*$data(-polyphase)}]
	    set log2size [::capture::log2-size $ns]
	    if {[$data(tap) cget -log2size] != $log2size} {
		$data(tap) configure -log2size $log2size
	    }
	    if { ! [info exists data(fft-window)] ||
		 [string length $data(fft-window)] != $ns*4} {
		set data(fft-window) [sdrtcl::window-polyphase $data(-polyphase) $data(-size)]
	    }
	} else {
	    set ns $data(-size)
	    set log2size [::capture::log2-size $ns]
	    if {[$data(tap) cget -log2size] != $log2size} {
		$data(tap) configure -log2size $log2size
	    }
	    if { ! [info exists data(fft-window)] ||
		 [string length $data(fft-window)] != $ns*4} {
		set data(fft-window) [sdrtcl::window blackmanharris $data(-size)]
	    }
	}
	# capture a buffer
	lassign [::$data(tap) get] f b
	# don't pass it on if its short
	set ni [expr {[string length $b]/8}]
	if {$ni < $ns} {
	    # puts "capture buffer too small $ni < $ns (-log2size is [$data(tap) cget -log2size], [::capture::log2-size $ns])"
	    # free the capture buffer
	    set b {}
	} else {
	    # compute the fft
	    set l [$data(fft) exec $b $data(fft-window)]
	    # free the capture buffer
	    set b {}
	    # convert the coefficients to a list
	    binary scan $l f* levels
	    # reorder the results from most negative frequency to most positive
	    # compute the power, and convert to pixels
	    ## they're ordered from 0 .. most positive, most negative .. just < 0
	    ## k/T, T = total sample time, n * 1/sample_rate
	    set xy {}
	    set x [expr {-[sdrtcl::jack sample-rate]/2.0}]
	    set dx [expr {[sdrtcl::jack sample-rate]/double($n)}]
	    set minp 1000
	    set maxp -1000
	    set avgp 0.0
	    # all the coefficients coming out of the fft are multiplied by sqrt(n)
	    # so 10*log10(coeff^2) is 10*log10(sqrt(n)^2) too big
	    set norm [expr {10*log10($n)}]
	    if { ! [catch {
		foreach {re im} [concat [lrange $levels $n end] [lrange $levels 0 [expr {$n-1}]]] {
		    # squared magnitude means 10*log10 dB
		    set p [expr {10*log10($re*$re+$im*$im+1e-64)-$norm}]
		    set maxp [expr {max($p,$maxp)}]
		    set avgp [expr {$avgp+$p/$n}]
		    set minp [expr {min($p,$minp)}]
		    lappend xy $x $p
		    set x [expr {$x+$dx}]
		}
	    }]} {
		# send the result to the client
		$data(-client) $w $xy minp $minp avgp $avgp maxp $maxp
	    }
	}
	# schedule next capture
	# puts "after $data(-period) [list ::capture::capture-spectrum $w]"
	after $data(-period) [list ::capture::capture-spectrum $w]
    }
}

proc ::capture::capture-iq {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# capture buffers and send the results to the client
	$data(-client) $w {*}[::$data(tap) get]
	# schedule next capture
	after $data(-period) [list ::capture::capture-iq $w]
    }
}

proc ::capture::capture-midi {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# capture a buffer and send the result to the client
	set midi [::$data(tap) get]
	if {[llength $midi] > 0} { $data(-client) $w $midi }
	# schedule next capture
	after $data(-period) [list ::capture::capture-midi $w]
    }
}

proc ::capture::destroy {w} {
    upvar #0 ::capture::$w data
    catch {rename $data(tap) {}}
    catch {rename $data(fft) {}}
    catch {rename $data(iq) {}}
    catch {rename $data(midi) {}}
}

proc ::capture::state {w} {
    upvar #0 ::capture::$w data
    #puts "state $w has data {[array get data]}"
    if {[catch {$data(tap) state} result]} {
	#puts "$data(tap) state returned $result"
	return {nonexistent}
    }
    return $result
}

proc ::capture::start {w} {
    upvar #0 ::capture::$w data
    #puts "::capture::start $w has data {[array get data]}"
    #puts "$w state  [state $w]"
    if { ! $data(started)} {
	#puts "start $data(tap) of $data(type)"
	$data(tap) start
	#puts "::capture::start $w has state [state $w]"
	set data(started) 1
	after 100 [list ::capture::capture-$data(type) $w]
    }
}

proc ::capture::stop {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	set data(started) 0
	$data(tap) stop
    }
}

proc ::capture::spectrum {w args} {
    #puts "::capture::spectrum $w {$args}"
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) spectrum
    set data(tap) "capture_spectrum_[incr ::capture::ntap]"
    set data(fft) "capture_fft_[incr ::capture::ntap]"
    #puts "creating $data(fft)"
    ::sdrtcl::fftw $data(fft) -size $data(-size)
    #puts "creating $data(tap)"
    ::sdrtcl::audio-tap $data(tap) -log2n 2 -log2size [::capture::log2-size $data(-size)] -complex 1
    #puts "configuring $data(tap)"
    ::capture::configure $w {*}$args
}

proc ::capture::iq {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) iq
    set data(tap) "capture_iq_[incr ::capture::ntap]"
    ::sdrtcl::audio-tap $data(tap) -log2n 2 -log2size [::capture::log2-size $data(-size)] -complex 0
    ::capture::configure $w {*}$args
}

proc ::capture::midi {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) midi
    set data(tap) "capture_midi_[incr ::capture::ntap]"
    ::sdrtcl::midi-tap $data(tap)
    ::capture::configure $w {*}$args
}

