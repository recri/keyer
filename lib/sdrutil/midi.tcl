# -*- mode: tcl; tab-width: 8 -*-

package provide midi 0.1

#
# read a midi packet and dispatch it
# format a midi packet and send it
# translate midi notes and velocities
#
# Copyright (c) 2010 by Roger E Critchlow Jr, Santa Fe, NM, USA
#

namespace eval ::midi {

    ##
    ## decoding raw midi commands
    ## read from the input port named $in
    ## dispatch to the namespace named $target
    ## with the context argument $w
    ##
    proc decode {target w in} {
	upvar #0 $in inport
	binary scan $inport ccc b0 b1 b2
	set channel [expr {$b0 & 0xf}]
	switch [expr {($b0 & 0xF0)>>4}] {
	    8  { ${target}::note-off $w $channel $b1 $b2 }
	    9  { ${target}::note-on $w $channel $b1 $b2 }
	    10 { ${target}::note-aftertouch $w $channel $b1 $b2 }
	    11 { ${target}::control-change $w $channel $b1 $b2 }
	    12 { ${target}::program-change $w $channel $b1 }
	    13 { ${target}::channel-pressure $w $channel $b1 }
	    14 { ${target}::pitchwheel-change $w $channel [expr {($b1|($b2<<7))-0x2000}] }
	}
    }

    ##
    ## formatting midi commands
    ## format the specified midi command as binary bytes
    ## and store it into the output port named $out
    ##
    proc note-off {out channel note velocity} {
	uplevel #0 [list set $out [binary format ccc [expr {0x80|($channel&0xF)}] [expr {$note&0x7f}] [expr {$velocity&0x7f}]]]
    }
    proc note-on {out channel note velocity} {
	uplevel #0 [list set $out [binary format ccc [expr {0x90|($channel&0xF)}] [expr {$note&0x7f}] [expr {$velocity&0x7f}]]]
    }
    proc note-aftertouch {out channel note velocity} {
	uplevel #0 [list set $out [binary format ccc [expr {0xA0|($channel&0xF)}] [expr {$note&0x7f}] [expr {$velocity&0x7f}]]]
    }
    proc control-change {out channel control value} {
	uplevel #0 [list set $out [binary format ccc [expr {0xB0|($channel&0xF)}] [expr {$control&0x7f}] [expr {$value&0x7f}]]]
    }
    proc program-change {out channel program} {
	uplevel #0 [list set $out [binary format ccc [expr {0xC0|($channel&0xF)}] [expr {$program&0x7f}]]]
    }
    proc channel-pressure {out channel pressure} {
	uplevel #0 [list set $out [binary format ccc [expr {0xD0|($channel&0xF)}] [expr {$pressure&0x7f}]]]
    }
    proc pitchwheel-change {out channel bend} {
	uplevel #0 [list set $out [binary format ccc [expr {0xE0|($channel&0xF)}] [expr {$bend&0x7f}] [expr {($bend>>7)&0x7f}]]]
    }

    ##
    ## names for midi note numbers
    ##
    array set notes {
	lowest			0
	lowest_piano		21
	lowest_bass_clef	43
	highest_bass_clef	57
	middle_C		60
	lowest_treble_clef	64
	A_440			69
	highest_treble_clef	77
	highest_piano		108
	highest			127
    
	C	60
	C_sharp	61
	D_flat	61
	D	62
	D_sharp	63
	E_flat	63
	E	64
	F	65
	F_sharp	66
	G_flat	66
	G	67
	G_sharp	68
	A_flat	68
	A	69
	A_sharp	70
	B_flat	70
	B	71
	octave {C C# D D# E F F# G G# A A# B}
    }

    ##
    ## midi translations
    ##

    # compute the standard frequency of a midi note number
    proc note-to-hertz {note} { return [expr {440.0 * pow(2, ($note-$::midi::notes(A_440))/12.0)}] }

    # precompute the result
    variable cache-note-to-hertz {}
    for {set m 0} {$m < 128} {incr m} {
	lappend cache-note-to-hertz [note-to-hertz $m]
    }

    # convert a midi note into a frequency in Hertz
    proc mtof {note} { lindex ${::midi::cache-note-to-hertz} $note }
    
    # compute a note name of a midi note number
    proc note-to-name {note} { return [lindex $::midi::notes(octave) [expr {$note%12}]] }
    proc name-to-note {name} { return [lsearch $::midi::notes(octave) $name] }

    # compute the standard octave of a midi note number
    proc note-to-octave {note} { return [expr {($note/12)-1}] }
    proc octave-to-note {octave} { return [expr {($octave+1)*12}] }

    # convert note name to midi note
    proc name-octave-to-note {name} {
	if {[regexp {^([A-G])(\d*)(#?)$} $name all note octave sharp]} {
	    return [expr {[octave-to-note $octave]+[name-to-note $note$sharp]}]
	}
	error "$name did not match regexp"
    }

    # translate a midi velocity to a level
    proc velocity-to-level {velocity} {
	return [expr {$velocity / 127.0}]
    }

    variable cache-velocity-to-level {}
    for {set m 0} {$m < 128} {incr m} {
	lappend cache-velocity-to-level [velocity-to-level $m]
    }

    proc vtol {vel} { lindex ${::midi::cache-velocity-to-level} $vel }
}
