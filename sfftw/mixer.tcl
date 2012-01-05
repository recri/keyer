package provide mixer 1.0

namespace eval ::mixer:: {
}

proc mixer-page {w} {
    upvar \#0 $w data

    #
    # ::snack::mixerDialog expanded inline
    # add -
    #	mute?
    #	lock stereo channel controls?
    #	save/restore initial settings?
    #	disable microphone line attenuator?
    #	monitor for changes from other controls?
    #
    pack [frame $w.f]
    foreach line [snack::mixer lines] {
	pack [frame $w.f.g$line -bd 1 -relief solid] -side left -expand yes -fill both
	pack [label $w.f.g$line.l -text $line]
	if {[snack::mixer channels $line] == "Mono"} {
	    snack::mixer volume $line v(r$line)
	} else {
	    snack::mixer volume $line v(l$line) v(r$line)
	    pack [scale $w.f.g$line.e -from 100 -to 0 -show no -var v(l$line)] -side left -expand yes -fill both
	}
	pack [scale $w.f.g$line.s -from 100 -to 0 -show no -var v(r$line)] -expand yes -fill both
    }
	
    pack [frame $w.f.f2] -side left
	
    if {[snack::mixer inputs] != ""} {
	pack [label $w.f.f2.li -text "Input jacks:"]
	foreach jack [snack::mixer inputs] {
	    snack::mixer input $jack [namespace current]::v(in$jack)
	    pack [checkbutton $w.f.f2.b$jack -text $jack -variable [namespace current]::v(in$jack)] -anchor w
	}
    }
    if {[snack::mixer outputs] != ""} {
	pack [label $w.f.f2.lo -text "Output jacks:"]
	foreach jack [snack::mixer outputs] {
	    snack::mixer lines $jack [namespace current]::v(out$jack)
	    pack [checkbutton $w.f.f2.b$jack -text $jack -variable [namespace current]::v(out$jack)] -anchor w
	}
    }

}

proc mixer-raise args { }
proc mixer-leave args { return 1 }

