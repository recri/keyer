package provide keyer-control 1.0.0

package require keyer
package require sdrkit

namespace eval keyer-control {

}

#
# update a variable and send it's value onward
#
proc keyer-control::client-config {client opt scale value} {
    global data
    if {$scale == 1} {
	set value [format %.0f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 10} {
	set value [format %.1f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 100} {
	set value [format %.2f [expr {double($value)/double($scale)}]]
    } elseif {$scale == 1000} {
	set value [format %.3f [expr {double($value)/double($scale)}]]
    }
    set data($client-$opt-display) $value
    $client config -$opt $value
}

#
# generic control panel row
#
proc keyer-control::panel-row {w client row opt label from to units} {
    global data
    grid [ttk::label $w-o -text $opt] -row $row -column 0 -sticky w
    grid [ttk::label $w-l -text $label] -row $row -column 1
    if {[llength $from] > 1} {
	grid [ttk::frame $w-s] -row $row -column 2 -sticky w
	foreach x $from {
	    pack [ttk::radiobutton $w-s.x$x -text $x -variable data($client-$opt) -value $x -command [list client-config $client $opt $x]] -side left -anchor w
	}
    } else {
	set scale 1
	switch -regexp $from {
	    {^-?\d+$} { set scale 1 }
	    {^-?\d+.\d$} { set scale 10 }
	    {^-?\d+.\d\d$} { set scale 100 }
	}
	grid [ttk::scale $w-s -orient horizontal -from [expr {$from*$scale}] -to [expr {$to*$scale}] -length 250 \
		  -variable data($client-$opt-scale) -command [list keyer-control::client-config $client $opt $scale]] -row $row -column 2 -sticky ew
	set data($client-$opt-scale) [expr {$data($client-$opt)*$scale}]
	keyer-control::client-config $client $opt $scale $data($client-$opt-scale)
	grid [ttk::label $w-v -textvar data($client-$opt-display)] -row $row -column 3 -sticky e
	if {$units ne {}} {
	    grid [ttk::label $w-u -text $units] -row $row -column 4 -sticky w
	}
    }
}

#
# configure ascii keyer options
#
proc keyer-control::ascii-frame {w client row} {
    global data
    foreach {opt label from to units} {
	wpm {words / minute} 5.0 60.0 {}
	word {word length} 40 70 dits
	dah {dah length} 2.5 3.5 dits
	ies {inter-element length} 0.5 1.5 dits
	ils {inter-letter length} 2.5 3.5 dits
	iws {inter-word length} 5 20 dits
    } {
	keyer-control::panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure iambic keyer options
#
proc keyer-control::iambic-frame {w client row} {
    global data
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
	keyer-control::panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure tone options
#
proc keyer-control::tone-frame {w client row} {
    global data
    foreach {opt label from to units} {
	freq {tone frequency} 300.0 1000.0 Hz
	gain {tone volume} -40.0 0.0 dB
	rise {key rise time} 0.1 50.0 ms
	fall {key fall time} 0.1 50.0 ms
    } {
	keyer-control::panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure MIDI options
#
proc keyer-control::midi-frame {w client row} {
    global data
    foreach {opt label from to units} {
	chan {midi channel} 1 16 {}
	note {midi note} 0 127 {}
    } {
	keyer-control::panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure keyer options
#
proc keyer-control::panel {w ascii ascii_tone iambic iambic_tone opts} {
    global data
    array set data $opts
    puts "initialized data with $opts"

    ttk::frame $w
    set row 0

    if {$data(ascii)} {
	grid [label $w.ascii -text {Ascii Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::tone-frame $w ascii_tone [incr row]]
	grid [label $w.ascii2 -text {Ascii Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::ascii-frame $w ascii [incr row]]
	grid [label $w.ascii3 -text {Ascii Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w ascii [incr row]]
    }

    if {$data(iambic)} {
	grid [label $w.iambic -text {Iambic Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::tone-frame $w iambic_tone [incr row]]
	grid [label $w.iambic2 -text {Iambic Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::iambic-frame $w iambic [incr row]]
	grid [label $w.iambic3 -text {Iambic Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [keyer-control::midi-frame $w iambic [incr row]]
    }

    return $w
}

proc keyer-control {w ascii ascii_tone iambic iambic_tone opts} {
    pack [keyer-control::panel $w $ascii $ascii_tone $iambic $iambic_tone $opts]
}

