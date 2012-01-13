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
}

proc ::capture::configure {w args} {
    upvar #0 ::capture::$w data
    foreach {option value} $args {
	switch -- $option {
	    -size {
		if {$value != $data(-size)} {
		    set data(-size) $value
		    catch {rename $data(fft) {}}
		    ::sdrkit::fftw $data(fft) -size $value
		}
		set data($option) $value
	    }
	    -period {
		set data($option) $value
	    }
	    -connect {
		foreach x $value {
		    catch {sdrkit::jack connect $x:out_i $data(tap):in_i}
		    catch {sdrkit::jack connect $x:out_q $data(tap):in_q}
		}
		set data($option) $value
	    }
	    default {
		set data($option) $value
	    }
	}
    }
}

proc ::capture::capture {w} {
    upvar #0 ::capture::$w data

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
	lappend xy $x [expr {10*log10($re*$re+$im*$im+1e-16)}]
	set x [expr {$x+$dx}]
    }

    # send the result to the client
    $data(-client) $w $xy

    # schedule next capture
    after $data(-period) [list ::capture::capture $w]
}

proc ::capture::spectrum {w args} {
    upvar #0 ::capture::$w data
    array set data [array get ::capture::default_data]
    set data(tap) capture$::capture::ntap
    set data(fft) capture_fft_$::capture::ntap
    incr ::capture::ntap
    ::sdrkit::atap $data(tap)
    ::capture::configure $w {*}$args
    after 500 [list ::capture::capture $w]
}

