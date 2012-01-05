package provide spectrogram 1.0
package require snack
package require params

namespace eval ::spectrogram:: {
}

proc spectrogram-page {w} {
    upvar \#0 $w data

    # menubar
    pack [frame $w.m] -side top -anchor w
    
    # menues
    foreach m {fftlength windowtype winlength preemphasisfactor topfrequency channel contrast brightness colormap} {
	pack [::params::any-menu $w $w.m.$m [list ::spectrogram::configure $w $m] spectrogram $m] -side left -anchor w
    }

    # canvas
    pack [canvas $w.c -width 400 -height 400] -side top -expand true -fill both

    # spectrogram
    set data(spectrogram) [$w.c create spectrogram 10 10 -anchor nw -width 380 -height 380]
}

proc spectrogram-raise args { }
proc spectrogram-leave args { return 1 }

proc ::spectrogram::configure {w option} {
    upvar \#0 $w data
    return
    if {$data(winlength) > $data(fftlength)} {
	error "window length must be less than or equal to fft length"
    }
    switch $option {
	default {
	    $w.c itemconfigure $data(spectrogram) -$option $data($option)
	}
    }
}
