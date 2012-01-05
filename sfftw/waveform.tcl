package provide waveform 1.0
package require snack
package require params

namespace eval ::waveform:: {
}

proc waveform-page {w} {
    upvar \#0 $w data

    # menubar
    pack [frame $w.m] -side top -anchor w

    # menues
    foreach m {channel limit zerolevel pixelspersecond subsample} {
	pack [::params::any-menu $w $w.m.$m [list ::waveform::configure $w $m] waveform $m] -side left -anchor w
    }

    # canvas
    pack [canvas $w.c -width 400 -height 400] -side top -expand true -fill both

    # waveform
    set data(waveform) [$w.c create waveform 10 10 -anchor nw -width 380 -heigh 380 -frame true -fill white]
}

proc waveform-raise args { }
proc waveform-leave args { return 1 }

proc ::waveform::configure {w option} {
    upvar \#0 $w data
    return
    switch $option {
	default {
	    $w.c itemconfigure $data(waveform) -$option $data($option)
	}
    }
}
