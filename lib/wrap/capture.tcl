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
package require sdrkit::audio-tap
package require sdrkit::midi-tap
package require sdrkit::fftw
package require sdrkit::jack

namespace eval ::capture {
    set ntap 0
    array set default_data {
	-connect {}
	-period 50
	-size 4096
    }
}

proc ::capture::log2-size {n} {
    #puts "::capture::log2-size $n -> max([::sdrkit::log2-size $n],[::sdrkit::log2-size [::sdrkit::jack buffer-size]])"
    return [expr {max([::sdrkit::log2-size $n],[::sdrkit::log2-size [::sdrkit::jack buffer-size]])}]
}

proc ::capture::configure {w args} {
    upvar #0 ::capture::$w data
    #puts "::capture::configure $w {$args} with data {[array get data]}"
    #puts "$w state  [::capture::state $w]"
    foreach {option value} $args {
	switch -- $option {
	    -size {
		if {$value != $data(-size)} {
		    set data(-size) $value
		    if {$data(type) eq {spectrum}} {
			$data(fft) configure -size $value
			$data(tap) configure -log2n 4 -log2size [::capture::log2-size $value]
		    }
		    if {$data(type) eq {iq} && [info exists data(tap)]} {
			$data(tap) configure -log2size [::capture::log2size $value]
		    }
		}
		set data($option) $value
	    }
	    -period {
		set data($option) $value
	    }
	    -connect {
		switch $data(type) {
		    midi {
			foreach x $value {
			    catch {sdrkit::jack connect $x $data(tap):midi_in}
			}
		    }
		    iq - spectrum {
			foreach x $value {
			    catch {sdrkit::jack connect $x:out_i $data(tap):in_i}
			    catch {sdrkit::jack connect $x:out_q $data(tap):in_q}
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
	# capture a buffer
	lassign [::$data(tap) get] f b
	# don't pass it on if its short
	if {[string length $b]/8 >= $n} {
	    # compute the fft
	    set l [::$data(fft) exec $b]
	    # free the capture buffer
	    set b {}
	    # convert the coefficients to a list
	    binary scan $l f* levels
	    # reorder the results from most negative frequency to most positive
	    # compute the power, and convert to pixels
	    ## they're ordered from 0 .. most positive, most negative .. just < 0
	    ## k/T, T = total sample time, n * 1/sample_rate
	    set xy {}
	    set x [expr {-[sdrkit::jack sample-rate]/2.0}]
	    set dx [expr {[sdrkit::jack sample-rate]/double($n)}]
	    foreach {re im} [concat [lrange $levels [expr {1+$n}] end] [lrange $levels 0 $n]] {
		# squared magnitude means 10*log10 dB
		lappend xy $x [expr {10*log10($re*$re+$im*$im+1e-64)}]
		set x [expr {$x+$dx}]
	    }
	    # send the result to the client
	    $data(-client) $w $xy
	} else {
	    # free the capture buffer
	    set b {}
	}
	# schedule next capture
	after $data(-period) [list ::capture::capture-spectrum $w]
    }
}

proc ::capture::capture-iq {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# capture buffers and send the results to the client
	while {[llength [set capture [::$data(tap) get]]] > 0} {
	    $data(-client) $w {*}$capture
	}
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
    ::sdrkit::fftw $data(fft) -size $data(-size)
    #puts "creating $data(tap)"
    ::sdrkit::audio-tap $data(tap) -log2n 2 -log2size [::capture::log2-size $data(-size)] -complex 1
    #puts "configuring $data(tap)"
    ::capture::configure $w {*}$args
}

proc ::capture::iq {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) iq
    set data(tap) "capture_iq_[incr ::capture::ntap]"
    ::sdrkit::audio-tap $data(tap) -log2n 2 -log2size [::capture::log2-size $data(-size)] -complex 0
    ::capture::configure $w {*}$args
}

proc ::capture::midi {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) midi
    set data(tap) "capture_midi_[incr ::capture::ntap]"
    ::sdrkit::midi-tap $data(tap)
    ::capture::configure $w {*}$args
}

