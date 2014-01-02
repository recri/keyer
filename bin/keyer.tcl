#!/usr/bin/tclsh8.6

# get the script full path
set script [info script]

# append the ../lib directory to the Tcl search path
lappend auto_path [file join [file dirname $script] .. lib]

# find the name of the script, without reading links
set name [file tail $script]

# need tk for the key input events, the ui, the event loop
package require Tk

# need snack to make sounds
package require snack

# radio menu button widget
package require sdrtk::radiomenubutton

# fft windowing functions for attack/decay envelopes
package require sdrtcl::window

# morse code tables
package require morse::morse
package require morse::itu

#
# build up a keyer
#
set pi [expr {atan2(0, -1)}]

snack::audio playLatency 100

array set data {
    samplerate 48000
    options {
	freq gain keyer wpm envelope attack decay
	dit-per-dah dit-per-ies dit-per-ils dit-per-iws
	dit dah ies ils iws
	sounds dits dahs
    }
    freq-data {my-scale f 500.0 300 1200 %.0f Hz {} {}}
    attack-data {my-scale a 5.0 0.0 10.0 %.1f ms {} {}}
    decay-data {my-scale d 5.0 0.0 10.0 %.1f ms {} {}}
    gain-data {my-scale g 1.0 0.1 2.0 %.2f {} {} {}}
    wpm-data {my-scale s 10.0 5 30 %.0f wpm {} {}}
    dit-per-dah-data {my-scale d1 3.0 2.5 3.5 %.1f {} {} {}}
    dit-per-ies-data {my-scale d2 1.0 0.5 1.5 %.1f {} {} {}}
    dit-per-ils-data {my-scale d3 3.0 2.5 3.5 %.1f {} {} {}}
    dit-per-iws-data {my-scale d4 7.0 6.0 8.0 %.1f {} {} {}}
    dit-data {my-label e1 %.6f sec {wpm} {update-dit}}
    dah-data {my-label e2 %.6f sec {dit dit-per-dah} {update-dah}}
    ies-data {my-label e3 %.6f sec {dit dit-per-ies} {update-ies}}
    ils-data {my-label e4 %.6f sec {dit dit-per-ils} {update-ils}}
    iws-data {my-label e5 %.6f sec {dit dit-per-iws} {update-iws}}
    envelope-data {
	my-choice e blackman-harris {
	    rectangular hanning welch parzen bartlett hamming blackman2 blackman3 blackman4 exponential
	    riemann blackman-harris blackman-nuttall nuttall flat-top tukey cosine lanczos triangular
	    gaussian bartlett-hann kaiser
	} {} {}
    }
    keyer-data {
	my-choice k iambic-k1el {
	    iambic-ad5dz iambic-dttsp iambic-k1el iambic-nd7pa straight
	} {} {}
    }
    sounds-data { my-button u make-sounds {freq gain envelope attack decay dit dah ies ils iws} {update-sounds}}
    dits-data { my-button u1 make-dits {} {} }
    dahs-data { my-button u2 make-dahs {} {} }
}

proc update-dit {args} {
    set ::data(dit) [expr {1.2/$::data(wpm)}]
}
proc update-dah {args} {
    set ::data(dah) [expr {$::data(dit)*$::data(dit-per-dah)}]
}
proc update-ies {args} {
    set ::data(ies) [expr {$::data(dit)*$::data(dit-per-ies)}]
}
proc update-ils {args} {
    set ::data(ils) [expr {$::data(dit)*$::data(dit-per-ils)}]
}
proc update-iws {args} {
    set ::data(iws) [expr {$::data(dit)*$::data(dit-per-iws)}]
}
proc update-sounds {args} {
    make-sounds
}

proc my-label {w name} {
    lassign $::data($name-data) cmd f fmt unit deps update
    ttk::labelframe $w.$f -text $name
    pack [ttk::label $w.$f.l -textvariable ::data($name-display)] -side left
    pack [ttk::label $w.$f.u -text $unit]
    trace add variable ::data($name) write [list my-label-var-update $w.$f $name $fmt]
    foreach dep $deps {
	if {$update ne {}} {
	    trace add variable ::data($dep) write $update
	    $update
	}
    }
    my-label-var-update $w.$f $name $fmt
    return $w.$f
}

proc my-label-var-update {w name fmt args} {
    # puts "my-label-var-update $w $name $fmt $args"
    set ::data($name-display) [format $fmt $::data($name)]
}

proc my-scale {w name} {
    lassign $::data($name-data) cmd f val min max fmt unit deps update
    # puts "name=$name f=$f val=$val min=$min max=$max fmt=$fmt unit=$unit"
    ttk::labelframe $w.$f -text $name
    pack [ttk::scale $w.$f.s -from $min -to $max -variable ::data($name)] -side left
    pack [ttk::label $w.$f.l -textvariable ::data($name-display) -width 8] -side left
    pack [ttk::label $w.$f.u -text $unit -width 4] -side left
    trace add variable ::data($name) write [list my-scale-var-update $w.$f $name $fmt]
    # puts "deps={$deps} update=$update"
    if {$update ne {}} {
	foreach dep $deps {
	    trace add variable ::data($dep) write $update
	}
    }
    set ::data($name) $val
    return $w.$f
}

proc my-scale-var-update {w name fmt args} {
    # puts "my-scale-var-update $w $name $fmt $args"
    set ::data($name-display) [format $fmt $::data($name)]
}

proc my-choice {w name} {
    lassign $::data($name-data) cmd f val choice deps update
    # puts "name=$name f=$f val=$val choice=$choice"
    ttk::labelframe $w.$f -text $name
    pack [sdrtk::radiomenubutton $w.$f.m -variable ::data($name) -values $choice]
    if {$update ne {}} {
	foreach dep $deps {
	    trace add variable ::data($dep) write $update
	}
    }
    set ::data($name) $val
    return $w.$f
}

proc my-button {w name} {
    lassign $::data($name-data) cmd f action deps update
    ttk::button $w.$f -text "make $name" -command [list $action]
    if {$update ne {}} {
	foreach dep $deps {
	    trace add variable ::data($dep) write $update
	}
    }
    return $w.$f
}

proc make-ui {w} {
    set row -1
    foreach name $::data(options) {
	# puts "$name -> $::data($name-data)"
	set cmd [lindex $::data($name-data) 0]
	grid [$cmd $w $name] -row [incr row] -column 0
    }
    return $w
}

proc make-sound {sound} {
    catch {$sound destroy}
    snack::sound $sound -rate $::data(samplerate) -channels 1
    set n [expr {int($::data($sound) * $::data(samplerate))}]
    if {$sound in {dit dah}} {
	set na [expr {int($::data(attack) * $::data(samplerate) / 1000.0)}]
	set nd [expr {int($::data(decay) * $::data(samplerate) / 1000.0)}]
	if {$na + $nd > $n} {
	    binary scan [sdrtcl::window $::data(envelope) $n] f* wts
	} else {
	    binary scan [sdrtcl::window $::data(envelope) [expr {2*$na+1}]] f* awts
	    set awts [lrange $awts 0 [expr {$na-1}]]
	    binary scan [sdrtcl::window $::data(envelope) [expr {2*$nd+1}]] f* dwts
	    set dwts [lrange $dwts [expr {$nd}] [expr {2*$nd}]]
	    set wts [concat $awts [lrepeat [expr {$n-$na-$nd}] 1.0] $dwts]
	}
	set t 0
	set dt [expr {2*$::pi*$::data(freq)/$::data(samplerate)}]
	foreach w $wts {
	    lappend samples [expr {int(32767*$w*$::data(gain)*sin($t))}]
	    set t [expr {$t+$dt}]
	}
    } else {
	for {set i 0} {$i < $n} {incr i} {
	    lappend samples 0
	}
    }
    if {$sound eq {dit}} {
	# puts "$sound: [lrange $samples 0 512]"
    }
    set samples [binary format s* $samples]
    $sound data $samples
    if {$sound eq {dit}} {
	# binary scan [$sound data] s* samples
	# puts "$sound: [lrange $samples 0 512]"
    }
}

proc make-sounds {} {
    foreach sound {dit dah ies ils iws} {
	make-sound $sound
    }
}

proc make-dits {args} {
    switch $args {
	{} {
	    # puts make-dits
	    make-dits stop
	    make-dahs stop
	    make-dits dit
	}
	dit {
	    playback concatenate dit
	    playback play -command [list make-dits ies]
	    #dit play -command [list make-dits ies]
	}
	ies {
	    playback concatenate ies
	    playback play -command [list make-dits dit]
	    #ies play -command [list make-dits dit]
	}
	stop {
	    catch {playback stop}
	    #catch {dit stop}
	    #catch {ies stop}
	}
    }
}

proc make-dahs {args} {
    switch $args {
	{} {
	    #puts make-dahs
	    make-dits stop
	    make-dahs stop
	    make-dahs dah
	}
	dah {
	    playback concatenate dah
	    playback play -command [list make-dahs ies]
	    #dah play -command [list make-dahs ies]
	}
	ies {
	    playback concatenate ies
	    playback play -command [list make-dahs dah]
	    #ies play -command [list make-dahs dah]
	}
	stop {
	    catch {playback stop}
	    #catch {dah stop}
	    #catch {ies stop}
	}
    }
}

proc init {} {
    #catch {sdrtcl::window} msg; puts $msg
    #catch {sdrtcl::window foo 0} msg; puts $msg
    catch {sdrtcl::window foo 0} msg
    regsub {^unknown window type, should be one of } $msg {} msg
    regsub -all {, or |, } $msg { } msg
    set ::data(envelope-data) [lreplace $::data(envelope-data) 3 3 $msg]
    #puts $msg
}

proc main {argv} {
    pack [ttk::frame .f] -fill both -expand true
    make-ui .f
    snack::sound playback
    playback play
}


main $argv