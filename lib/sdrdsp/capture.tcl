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
##

package provide sdrdsp::capture 1.0.0

package require snit

package require sdrkit
package require sdrtcl::audio-tap
package require sdrtcl::midi-tap
package require sdrtcl::fftw
package require sdrtcl::window
package require sdrtcl::window-polyphase
package require sdrtcl::jack

::snit::type ::sdrdsp::capture {
    typevariable taps 0

    option -server {}
    option -connect -default {} -configuremethod handle-option
    option -period -default 50 -configuremethod handle-option
    option -size -default 4096 -configuremethod handle-option
    option -polyphase -default 0 -configuremethod handle-option
    option -type -default {} -readonly yes
    option -update {}

    variable data -array {
	started 0
	modified 0
	spectrum {}
	fft {}
	fft-window {}
	iq {}
	midi {}
    }

    proc log2-size {n} {
	#puts "::capture::log2-size $n -> max([::sdrtcl::log2-size $n],[::sdrtcl::log2-size [::sdrtcl::jack buffer-size]])"
	return [expr {max([::sdrtcl::log2-size $n],[::sdrtcl::log2-size [::sdrtcl::jack buffer-size]])}]
    }

    method connect {} { $self connection connect }
    method disconnect {} { $self connection disconnect }
    method connection {onoff} {
	switch $options(-type) {
	    midi {
		foreach x $options(-connect) {
		    sdrtcl::jack $onoff $x $data(midi):midi_in
		}
	    }
	    iq -
	    spectrum {
		foreach x $options(-connect) {
		    if {$x eq {system}} {
			sdrtcl::jack $onoff $x:capture_1 $data($options(-type)):in_i
			sdrtcl::jack $onoff $x:capture_2 $data($options(-type)):in_q
		    } else {
			sdrtcl::jack $onoff $x:out_i $data($options(-type)):in_i
			sdrtcl::jack $onoff $x:out_q $data($options(-type)):in_q
		    }
		}
	    }
	}
    }

    method handle-option {option value} {
	if { ! $data(started)} {
	    set options($option) $value
	} else {
	    switch -- $option {
		-size {
		    set data(modified) 1
		}
		-polyphase {
		    set data(modified) 1

		}
		-period {
		    set options($option) $value
		}
		-connect {
		    if {$options(-connect) ne {}} {
			$self stop
			$self disconnect
		    }
		    set options($option) $value
		    if {$options(-connect) ne {}} {
			$self connect
			$self start
		    }
		}
		default {
		    set options($option) $value
		}
	    }
	}
    }

    method capture-spectrum {} {
	if {$data(started)} {
	    # cache some numbers
	    set n $options(-size)
	    set ns $options(-size)
	    if {$options(-polyphase)} {
		set ns [expr {$ns*$options(-polyphase)}]
	    }
	    set log2size [log2-size $ns]

	    # check for configuration modifications
	    if {$data(modified)} {
		set data(modified) 0
		# make sure the fft is configured
		if {[$data(fft) cget -size] != $options(-size)} {
		    $data(fft) configure -size $options(-size)
		}
		# make sure the capture is configured
		if {[$data(spectrum) cget -log2size] != $log2size} {
		    $data(spectrum) configure -log2size $log2size
		}
		# make sure the window is configured,
		if {$options(-polyphase)} {
		    if {[string length $data(fft-window)] != $ns*4} {
			set data(fft-window) [sdrtcl::window-polyphase $options(-polyphase) $options(-size)]
		    }
		} else {
		    if {[string length $data(fft-window)] != $ns*4} {
			set data(fft-window) [sdrtcl::window blackmanharris $options(-size)]
		    }
		}
	    }

	    # capture a buffer
	    lassign [::$data(spectrum) get] f b

	    # don't pass it on if its short
	    set ni [expr {[string length $b]/8}]
	    if {$ni < $ns} {
		# puts "capture buffer too small $ni < $ns (-log2size is [$data(tap) cget -log2size], [::capture::log2-size $ns])"
		# free the captured buffer
		set b {}
	    } else {
		# compute the fft
		set l [$data(fft) exec $b $data(fft-window)]
		# free the captured buffer
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
			set p [expr {10*log10($re*$re+$im*$im+1e-16)-$norm}]
			set maxp [expr {max($p,$maxp)}]
			set avgp [expr {$avgp+$p/$n}]
			set minp [expr {min($p,$minp)}]
			lappend xy $x $p
			set x [expr {$x+$dx}]
		    }
		}]} {
		    # send the result to the client
		    if {$options(-update) ne {}} {
			{*}$options(-update) $xy minp $minp avgp $avgp maxp $maxp
		    }
		}
	    }
	    # schedule next capture
	    # puts "after $options(-period) [list ::capture::capture-spectrum $w]"
	    after $options(-period) [mymethod capture-spectrum]
	}
    }
    
    method capture-iq {} {
	if {$data(started)} {
	    # capture buffers and send the results to the client
	    if {$options(-update) ne {}} {
		{*}$options(-update) {*}[::$data(iq) get]
	    }
	    # schedule next capture
	    after $options(-period) [mymethod capture-iq]
	}
    }
    
    method capture-midi {} {
	if {$data(started)} {
	    # capture a buffer and send the result to the client
	    set midi [::$data(midi) get]
	    if {[llength $midi] > 0} {
		if {$options(-update) ne {}} {
		    {*}$options(-update) $midi
		}
	    }
	    # schedule next capture
	    after $options(-period) [mymethod capture-midi]
	}
    }
    
    method state {} {
	#puts "state $w has data {[array get data]}"
	if {[catch {$data($options(-type)) state} result]} {
	    return {nonexistent}
	}
	#puts "$data($options(-type)) state returned $result"
	return $result
    }
    
    method start {} {
	#puts "::capture::start $w has data {[array get data]}"
	#puts "$w state  [state $w]"
	if { ! $data(started)} {
	    switch $options(-type) {
		spectrum {
		    #puts "creating $data(fft)"
		    ::sdrtcl::fftw $data(fft) -size $options(-size)
		    #puts "creating $data(tap)"
		    ::sdrtcl::audio-tap $data(spectrum) -server $options(-server) -log2n 2 -log2size [log2-size $options(-size)] -complex 1
		}
		iq {
		    ::sdrtcl::audio-tap $data(iq) -server $options(-server) -log2n 2 -log2size [log2-size $options(-size)] -complex 0
		}
		midi {
		    ::sdrtcl::midi-tap $data(midi) -server $options(-server)
		}
	    }
	    # connect
	    $self connect
	    #puts "start $data(tap) of $data(type)"
	    $data($options(-type)) start
	    #puts "::capture::start $w has state [state $w]"
	    set data(started) 1
	    after 100 [list $self capture-$options(-type)]
	}
    }
    
    method stop {} {
	if {$data(started)} {
	    set data(started) 0
	    $data($options(-type)) stop
	    catch {rename $data($options(-type)) {}}
	    catch {rename $data(fft) {}}
	}
    }
    
    destructor {
	catch {rename $data($options(-type)) {}}
	catch {rename $data(fft) {}}
    }

    constructor {args} {
	#puts "::capture::spectrum $w {$args}"
	# this will blow up when handling options
	$self configure {*}$args
	switch $options(-type) {
	    spectrum {
		set data(spectrum) "::spectrum_[incr taps]"
		set data(fft) "::fft_$taps"
	    }
	    iq { set data(iq) "::iq_[incr taps]" }
	    midi { set data(midi) "::midi_[incr taps]" }
	}
    }
}    
