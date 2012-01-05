#
# this package wraps the Snack section canvas item
#
package provide spectrum 1.0
package require snack
package require params

namespace eval ::spectrum:: {
}

proc spectrum-page {w} {
    upvar \#0 $w data

    # menubar
    pack [frame $w.m] -side top -anchor w

    # menues
    foreach m {fftlength windowtype winlength preemphasisfactor topfrequency channel minvalue maxvalue} {
	pack [::params::any-menu $w $w.m.$m [list ::spectrum::configure $w $m] section $m] -side left -anchor w
    }

    # canvas
    pack [canvas $w.c -width 400 -height 400] -side top

    # spectrum
    set data(spectrum) [$w.c create section 10 10 -anchor nw -width 380 -height 380 -frame true -fill white]
}

proc spectrum-raise args { }
proc spectrum-leave args { return 1 }

proc ::spectrum::configure {w option} {
    upvar \#0 $w data
    return
    if {$data(winlength) > $data(fftlength)} {
	error "window length must be less than or equal to fft length"
    }
    switch $option {
	default {
	    $w.c itemconfigure $data(spectrum) -$option $data($option)
	}
    }
}
