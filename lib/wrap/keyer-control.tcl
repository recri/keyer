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
package provide keyer-control 1.0.0

namespace eval ::keyer-control {}

#
# update a variable and send it's value onward
#
proc ::keyer-control::client-config {w client opt scale value} {
    upvar #0 ::keyer-control::$w data
    if {$scale eq {x}} {
	# no scaling, just use the value
    } elseif {$scale == 1} {
	set value [format %.0f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 10} {
	set value [format %.1f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 100} {
	set value [format %.2f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 1000} {
	set value [format %.3f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 10000} {
	set value [format %.4f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 100000} {
	set value [format %.5f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 1000000} {
	set value [format %.6f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 10000000} {
	set value [format %.7f [expr {double($value)/double($scale)}]]
    }
    set data($client-$opt-display) $value
    $client configure -$opt $value
}

#
# generic control panel row
#
proc ::keyer-control::panel-row {pw w client row opt label from to units} {
    upvar #0 ::keyer-control::$pw data
    grid [ttk::label $w-o -text $opt] -row $row -column 0 -sticky w
    grid [ttk::label $w-l -text $label] -row $row -column 1
    if {[llength $from] > 1} {
	grid [ttk::frame $w-s] -row $row -column 2 -sticky w
	foreach x $from {
	    pack [ttk::radiobutton $w-s.x$x -text $x -variable ::keyer-control::${pw}($client-$opt) -value $x \
		      -command [list ::keyer-control::client-config $pw $client $opt x $x]] -side left -anchor w
	}
    } else {
	set scale 1
	switch -regexp $from {
	    {^-?\d+$}              { set scale 1 }
	    {^-?\d+.\d$}	   { set scale 10 }
	    {^-?\d+.\d\d$}	   { set scale 100 }
	    {^-?\d+.\d\d\d$}       { set scale 1000 }
	    {^-?\d+.\d\d\d\d$}     { set scale 10000 }
	    {^-?\d+.\d\d\d\d\d$}   { set scale 100000 }
	    {^-?\d+.\d\d\d\d\d\d$} { set scale 1000000 }
	    default { error "missing case for computing scale of $from" }
	}
	grid [ttk::scale $w-s -orient horizontal -from [expr {$from*$scale}] -to [expr {$to*$scale}] -length 250 \
		  -variable ::keyer-control::${pw}($client-$opt-scale) \
		  -command [list keyer-control::client-config $pw $client $opt $scale]] -row $row -column 2 -sticky ew
	set data($client-$opt-scale) [expr {$data($client-$opt)*$scale}]
	keyer-control::client-config $pw $client $opt $scale $data($client-$opt-scale)
	grid [ttk::label $w-v -textvar ::keyer-control::${pw}($client-$opt-display)] -row $row -column 3 -sticky e
	if {$units ne {}} {
	    grid [ttk::label $w-u -text $units] -row $row -column 4 -sticky w
	}
    }
}

#
# configure ascii keyer options
#
proc ::keyer-control::ascii-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	wpm {words / minute} 5.0 60.0 {}
	word {word length} 40 70 dits
	dah {dah length} 2.5 3.5 dits
	ies {inter-element length} 0.5 1.5 dits
	ils {inter-letter length} 2.5 3.5 dits
	iws {inter-word length} 5 20 dits
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure iambic keyer options
#
proc ::keyer-control::iambic-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	wpm {words / minute} 5.0 60.0 {}
	word {word length} 40 70 dits
	dah {dah length} 2.5 3.5 dits
	ies {inter-element length} 0.5 1.5 dits
	ils {inter-letter length} 2.5 3.5 dits
	iws {inter-word length} 5 50 dits
	swap {swap paddles} {0 1} {} {}
	alsp {auto-letter space} {0 1} {} {}
	awsp {auto-word space} {0 1} {} {}
	mode {iambic mode} {A B} {} {}
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure tone options
#
proc ::keyer-control::tone-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	freq {tone frequency} 300.0 1000.0 Hz
	gain {tone volume} 0.0 -80.0 dB
	rise {key rise time} 0.1 50.0 ms
	fall {key fall time} 0.1 50.0 ms
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure MIDI options
#
proc ::keyer-control::midi-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	chan {midi channel} 1 16 {}
	note {midi note} 0 127 {}
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure PTT options
#
proc ::keyer-control::ptt-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	delay {ptt delay} 0.000 0.010 {seconds}
	hang {ptt hang} 0.00 2.00 {seconds}
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure Debounce options
#
proc ::keyer-control::debounce-frame {w client row} {
    upvar #0 ::keyer-control::$w data
    foreach {opt label from to units} {
	period {sampling period} 0.0001 0.0010 {seconds}
	steps {sampling steps} 0 64 {periods}
    } {
	keyer-control::panel-row $w $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure keyer options
#
proc ::keyer-control::panel {w opts} {
    upvar #0 ::keyer-control::$w data
    array set data $opts

    ttk::frame $w
    set row 0

    if {$data(client-ascii) ne {} && $data(client-ascii_tone) ne {}} {
	grid [label $w.ascii -text {Ascii Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::tone-frame $w $data(client-ascii_tone) [incr row]]
	grid [label $w.ascii2 -text {Ascii Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::ascii-frame $w $data(client-ascii) [incr row]]
	grid [label $w.ascii3 -text {Ascii Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w $data(client-ascii) [incr row]]
    }

    if {$data(client-iambic) ne {} && $data(client-iambic_tone) ne {}} {
	grid [label $w.iambic -text {Iambic Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::tone-frame $w $data(client-iambic_tone) [incr row]]
	grid [label $w.iambic2 -text {Iambic Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::iambic-frame $w $data(client-iambic) [incr row]]
	grid [label $w.iambic3 -text {Iambic Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w $data(client-iambic) [incr row]]
    }

    if {$data(client-ptt) ne {}} {
	grid [label $w.ptt -text {PTT Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::ptt-frame $w $data(client-ptt) [incr row]]
	grid [label $w.ptt2 -text {PTT Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w $data(client-ptt) [incr row]]
    }

    if {$data(client-debounce) ne {}} {
	grid [label $w.debounce -text {Key Debounce}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::debounce-frame $w $data(client-debounce) [incr row]]
	grid [label $w.debounce2 -text {Debounce Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w $data(client-debounce) [incr row]]
    }

    return $w
}

proc ::keyer-control {w opts} {
    return [keyer-control::panel $w $opts]
}

