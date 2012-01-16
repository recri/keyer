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

package require sdrkit::atap
package require sdrkit::audio-tap
package require sdrkit::mtap
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

proc ::capture::destroy {w} {
    upvar #0 ::capture::$w data
    catch {rename $data(tap) {}}
    catch {rename $data(fft) {}}
    catch {rename $data(iq) {}}
    catch {rename $data(midi) {}}
}

proc ::capture::configure {w args} {
    upvar #0 ::capture::$w data
    foreach {option value} $args {
	switch -- $option {
	    -size {
		if {$value != $data(-size)} {
		    set data(-size) $value
		    if {$data(type) eq {spectrum} && [info exists data(fft)]} {
			catch {rename $data(fft) {}}
			::sdrkit::fftw $data(fft) -size $value
		    }
		    if {$data(type) eq {iq} && [info exists data(tap)]} {
			$data(tap) configure -log2size [expr {int(log($data(-size))/log(2))}]
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
	set n  $data(-size)
	# capture a buffer
	foreach {f b} [::$data(tap) get $n] break
	# compute the fft
	set l [::$data(fft) exec $b]
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
	# schedule next capture
	after $data(-period) [list ::capture::capture-spectrum $w]
    }
}

proc ::capture::spectrum {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) spectrum
    set data(tap) capture$::capture::ntap
    set data(fft) capture_fft_$::capture::ntap
    incr ::capture::ntap
    ::sdrkit::atap $data(tap)
    ::capture::configure $w {*}$args
    #after 500 [list ::capture::capture-spectrum $w]
}

proc ::capture::capture-iq {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# capture a buffer and send the result to the client
	$data(-client) $w {*}[::$data(tap) get]
	# schedule next capture
	after $data(-period) [list ::capture::capture-iq $w]
    }
}

proc ::capture::iq {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) iq
    set data(tap) capture$::capture::ntap
    incr ::capture::ntap
    ::sdrkit::audio-tap $data(tap) -log2n 2 -log2size [expr {int(log($data(-size))/log(2))}]
    ::capture::configure $w {*}$args
}

proc ::capture::capture-midi {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	# capture a buffer and send the result to the client
	set midi [::$data(tap) gets]
	if {[llength $midi] > 0} { $data(-client) $w $midi }
	# schedule next capture
	after $data(-period) [list ::capture::capture-midi $w]
    }
}

proc ::capture::midi {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(started) 0
    set data(type) midi
    set data(tap) capture$::capture::ntap
    incr ::capture::ntap
    ::sdrkit::mtap $data(tap)
    ::capture::configure $w {*}$args
}

proc ::capture::start {w} {
    upvar #0 ::capture::$w data
    if { ! $data(started)} {
	set data(started) 1
	switch $data(type) {
	    spectrum { after 1 [list ::capture::capture-spectrum $w] }
	    iq { after 1 [list ::capture::capture-iq $w] }
	    midi { $data(tap) start; after 1 [list ::capture::capture-midi $w] }
	}
    }
}

proc ::capture::stop {w} {
    upvar #0 ::capture::$w data
    if {$data(started)} {
	set data(started) 0
	switch $data(type) {
	    spectrum { }
	    iq { }
	    midi { $data(tap) stop }
	}
    }
}
