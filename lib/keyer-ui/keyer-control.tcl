package provide keyer-control 1.0.0

namespace eval keyer-control {
    # default keyer parameters
    array set data {
	ascii 0
	iambic 1

	keyer-channel 1
	keyer-note 0

	ascii_tone-freq 700
	ascii_tone-gain -30
	ascii_tone-rise 5
	ascii_tone-fall 5

	ascii-wpm 15
	ascii-word 50
	ascii-dah 3
	ascii-ies 1
	ascii-ils 3
	ascii-iws 7

	iambic_tone-freq 750
	iambic_tone-gain -30
	iambic_tone-rise 5
	iambic_tone-fall 5

	iambic-wpm 15
	iambic-word 50
	iambic-dah 3
	iambic-ies 1
	iambic-ils 3
	iambic-iws 7
	iambic-mode A
	iambic-alsp 0
	iambic-awsp 0
	iambic-swap 0

    }
}

package require keyer
package require sdrkit

##
## parameters and operating data
##
array set data {
    ascii 1
    iambic 1

    #ascii_tone-verbose 5
    ascii_tone-freq 700
    ascii_tone-gain -30
    ascii_tone-rise 5
    ascii_tone-fall 5

    #ascii-verbose 5
    ascii-wpm 15
    ascii-word 50
    ascii-dah 3
    ascii-ies 1
    ascii-ils 3
    ascii-iws 7

    ascii-chan 1
    ascii-note 0

    #iambic_tone-verbose 5
    iambic_tone-freq 750
    iambic_tone-gain -30
    iambic_tone-rise 5
    iambic_tone-fall 5

    iambic-verbose 5
    iambic-wpm 15
    iambic-word 50
    iambic-dah 3
    iambic-ies 1
    iambic-ils 3
    iambic-iws 7
    iambic-mode A
    iambic-alsp 0
    iambic-awsp 0
    iambic-swap 0

    iambic-chan 1
    iambic-note 0
}

##
## plugin management
##
proc plug-exists {client} {
    global plug
    return [info exists plug($client)]
}

proc plug-open {command client {server default}} {
    global plug
    global data
    set args {}
    foreach name [array names data $client-*] {
	set val $data($name)
	set name [string range $name [expr {1+[string length $client]}] end]
	lappend args "-$name" $val
    }
    eval [concat [list $command $client -server $server] $args]
    set plug($client) $client
    lappend plug(clients) $client
}

proc plug-close {client} {
    global plug
    if {[plug-exists $client]} {
	foreach name [array names plug $client-*] {
	    unset plug($name)
	}
	set i [lsearch -exact $plug(clients) $client]
	set plug(clients) [lreplace $plug(clients) $i $i]
	rename $plug(client) {}
    } else {
	puts stderr "non-existent client $client in plug-close"
    }
}

proc plug-close-all {} {
    global plug
    foreach client $plug(clients) {
	plug-close $client
    }
}

proc plug-puts {client opt value} {
    global plug
    if {[plug-exists $client]} {
	#puts "$plug($client) config -$opt $value"
	$plug($client) config -$opt $value
	#puts "$plug($client) cget -$opt -> [$plug($client) cget -$opt]"
    } else {
	puts stderr "non-existent client $client in plug-puts"
    }
}

proc plug-puts-text {client text} {
    global plug
    if {[plug-exists $client]} {
	$plug($client) puts $text
    } else {
	puts stderr "non-existent client $client in plug-puts-text"
    }
}

proc plug-read {client} {
    global plug
    return [$plug($client) gets]
}

#
# initialize the plugged in helper applications
#
proc plug-init {} {
    global data
    # start jack
    # look for zombie helpers?
    set ports [sdrkit::jack list-ports]
    foreach port [dict keys $ports] {
	foreach conn [dict get $ports $port connections] {
	    switch -glob $line {
		ascii:* -
		iambic:* -
		ascii_tone:* -
		iambic_tone:* {
		    error "the [lindex [split $line :] 0] client is still running"
		}
	    }
	}
	switch -glob $port {
	    system:midi_capture_* {
		set midi_capture $port
	    }
	}
    }
    # make helpers
    set connects {}
    if {$data(ascii)} {
	plug-open keyer::ascii ascii
	plug-open keyer::tone ascii_tone
	lappend connects {sdrkit::jack connect ascii:midi_out ascii_tone:midi_in}
	lappend connects {sdrkit::jack connect ascii_tone:out_i system:playback_1}
	lappend connects {sdrkit::jack connect ascii_tone:out_q system:playback_2}
    }
    if {$data(iambic)} {
	if { ! [info exists midi_capture]} {
	    error "no midi_capture port for keyer connection"
	}
	# plug-open keyer::iambic iambic
	plug-open keyer::iambic iambic
	plug-open keyer::tone iambic_tone
	lappend connects [list sdrkit::jack connect $midi_capture iambic:midi_in]
	lappend connects {sdrkit::jack connect iambic:midi_out iambic_tone:midi_in}
	lappend connects {sdrkit::jack connect iambic_tone:out_i system:playback_1}
	lappend connects {sdrkit::jack connect iambic_tone:out_q system:playback_2}
    }
    # these names may need to change around
    after 500
    set retry {}
    foreach cmd $connects {
	if {[catch "eval $cmd" error]} {
	    puts "$cmd: yielded $error"
	    lappend retry $cmd
	}
    }
    foreach cmd $retry {
	if {[catch "eval $cmd" error]} {
	    puts "$cmd: failed again, yielded $error"
	}
    }
}

#
# play some text
#
proc play-text {text} {
    plug-puts-text ascii $text
}


#
# update a variable and send it's value onward
#
proc ui-plug-puts {client opt scale value} {
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
    plug-puts $client $opt $value
}

#
# generic control panel row
#
proc ui-panel-row {w client row opt label from to units} {
    global data
    grid [ttk::label $w-o -text $opt] -row $row -column 0 -sticky w
    grid [ttk::label $w-l -text $label] -row $row -column 1
    if {[llength $from] > 1} {
	grid [ttk::frame $w-s] -row $row -column 2 -sticky w
	foreach x $from {
	    pack [ttk::radiobutton $w-s.x$x -text $x -variable data($client-$opt) -value $x -command [list plug-puts $client $opt $x]] -side left -anchor w
	}
    } else {
	set scale 1
	switch -regexp $from {
	    {^-?\d+$} { set scale 1 }
	    {^-?\d+.\d$} { set scale 10 }
	    {^-?\d+.\d\d$} { set scale 100 }
	}
	grid [ttk::scale $w-s -orient horizontal -from [expr {$from*$scale}] -to [expr {$to*$scale}] -length 250 \
		  -variable data($client-$opt-scale) -command [list ui-plug-puts $client $opt $scale]] -row $row -column 2 -sticky ew
	set data($client-$opt-scale) [expr {$data($client-$opt)*$scale}]
	ui-plug-puts $client $opt $scale $data($client-$opt-scale)
	grid [ttk::label $w-v -textvar data($client-$opt-display)] -row $row -column 3 -sticky e
	if {$units ne {}} {
	    grid [ttk::label $w-u -text $units] -row $row -column 4 -sticky w
	}
    }
}

#
# configure ascii keyer options
#
proc ui-ascii-frame {w client row} {
    foreach {opt label from to units} {
	wpm {words / minute} 5.0 60.0 {}
	word {word length} 40 70 dits
	dah {dah length} 2.5 3.5 dits
	ies {inter-element length} 0.5 1.5 dits
	ils {inter-letter length} 2.5 3.5 dits
	iws {inter-word length} 5 20 dits
    } {
	ui-panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure iambic keyer options
#
proc ui-iambic-frame {w client row} {
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
	ui-panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure tone options
#
proc ui-tone-frame {w client row} {
    foreach {opt label from to units} {
	freq {tone frequency} 300.0 1000.0 Hz
	gain {tone volume} -40.0 0.0 dB
	rise {key rise time} 0.1 50.0 ms
	fall {key fall time} 0.1 50.0 ms
    } {
	ui-panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure MIDI options
#
proc ui-midi-frame {w client row} {
    foreach {opt label from to units} {
	chan {midi channel} 1 16 {}
	note {midi note} 0 127 {}
    } {
	ui-panel-row $w.$client-$opt $client $row $opt $label $from $to $units
	incr row
    }
    return $row
}

#
# configure keyer options
#
proc ui-control-panel {w} {
    global data
    ttk::frame $w
    set row 0


    if {$data(ascii)} {
	grid [label $w.ascii -text {Ascii Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-tone-frame $w ascii_tone [incr row]]
	grid [label $w.ascii2 -text {Ascii Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-ascii-frame $w ascii [incr row]]
	grid [label $w.ascii3 -text {Ascii Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-midi-frame $w ascii [incr row]]
    }

    if {$data(iambic)} {
	grid [label $w.iambic -text {Iambic Keyer Tone}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-tone-frame $w iambic_tone [incr row]]
	grid [label $w.iambic2 -text {Iambic Keyer Timing}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-iambic-frame $w iambic [incr row]]
	grid [label $w.iambic3 -text {Iambic Midi Options}] -row $row -column 0 -columnspan 5 -sticky w
	set row [ui-midi-frame $w iambic [incr row]]
    }

    return $w
}

#
# close the window
#
proc ui-close {w} {
    global data
    global score
    if {"$w" eq "."} {
	plug-close-all
	destroy .
    }
}

proc ui-input {k} {
    global data
    if {$data(ascii)} {
	plug-puts-text ascii $k
    }
}

#
# build a user interface
#
proc ui-init {} {
    pack [ui-control-panel .ctl]
    bind . <Destroy> [list ui-close %W]
    bind . <KeyPress> [list ui-input %A]
}

