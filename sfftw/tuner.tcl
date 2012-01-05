#
# an instrument tuner
#
package provide tuner 1.0
package require snack

namespace eval ::tuner:: {
    set notes {
	OCT
	#     C         C#        D        D#       E        F       F#      G      G#       A      A#       B
	0     .        .          .        .        .        .       .       .       .     27.5    19.135  30.868
	1   32.703   34.648     36.708   38.891   41.203   43.654  46.249  48.999  51.913  55.000  58.270  61.735
	2   65.406   69.296     73.416   77.782   82.407   87.307  92.499  97.999 103.83  110.00  116.54  123.47
	3  130.81   138.59     146.83   155.56   164.81   174.61  185.00  196.00  207.65  220.00  233.08  246.94
	4  261.63   277.18     293.66   311.13   329.63   349.23  369.99  392.00  415.30  440.00  466.16  493.88
	5  523.25   554.37     587.33   622.25   659.26   698.46  739.99  783.99  830.61  880.00  932.33  987.77
	6 1046.5   1108.7     1174.7    1244.5   1318.5  1396.9  1480.0  1568.0  1661.2  1760.0  1864.7  1975.5
	7 2093.0   2217.5     2349.3    2489.0   2637.0  2793.8  2960.0  3136.0  3322.4  3520.0  3729.3  3951.1
	8 4186.0   4434.9     4698.6    4978.0   5274.0  5587.7  5919.9  6271.9  6644.9  7040.0  7458.6  7902.1
    }
}

proc tuner-page {w} {
    upvar \#0 ::tuner::data data
    set data(window) $w
    pack [frame $w.m] -side top
    foreach m {fftlength windowtype winlength preemphasisfactor} {
	pack [::params::any-menu $w $w.m.$m [list ::tuner::configure $w $m] section $m] -side left -anchor w
    }
    pack [canvas $w.c -width 400 -height 200] -side top
    set data(section) [$w.c create section 10 10 -width 380 -height 180 -topfrequency 8000 -frame true]
}

proc tuner-raise {} {
    ::tuner::activate
}
proc tuner-leave {} {
    ::tuner::deactivate
    return 1
}

proc ::tuner::configure {w option} {
    upvar \#0 $w data
    return
    if {$data(winlength) > $data(fftlength)} {
	error "window length must be less than or equal to fft length"
    }
    switch $option {
	default {
	    $w.c itemconfigure $data(section) -$option $data($option)
	}
    }
}

proc ::tuner::activate {} {
    variable data
    if {[audio-active]} {
	set data(sound) [audio-sound]
	set data(after) [after 0 ::tuner::update]
    }
}
proc ::tuner::deactivate {} {
    variable data
    if {[audio-active]} {
	catch {after cancel $data(after)}
	catch {$data(window).c itemconfigure $data(section) -sound {}}
    }
}

proc ::tuner::update {} {
    variable data
    if {[catch {
	$data(window).c itemconfigure $data(section) -sound $data(sound)
	#puts [$data(sound) pitch]
    } error]} return
    set data(after) [after 100 ::tuner::update]
}

 
 