#
# a vfo dial with frequency readout
# adjustable display resolution,
# and turn resolution
#
# display resolution should be units (MHz kHz Hz} and precision {X X.XXX X.XXXXXX} independently
# turn resolution should be in terms of units/turn
# freq-changed should report precision digits, but keep the roundoff for turn tuning
# needs to step the frequency
#

package provide vfo 1.0
package require dial
package require Tk

namespace eval vfo {
    
    array set config {
	font {Helvetica 16}
	display-units {MHz kHz Hz}
	display-unit MHz
	display-unit-old MHz
	display-precisions {X X.XXX X.XXXXXX X.XXXXXXXXX}
	display-precision X.XXXXXX
	turn-resolutions {10 100 1000 10000 100000}
	turn-resolution 1000
	frequency 7050000
	frequency-changed ::vfo::ignore
	channel 0
	channels {
	    1.9 2.35 3.3 3.5 3.75 3.95 4.9 5 5.3 6 7 9.5 10 10.1 11.85 13.7
	    14 15 15.45 17.7 18.1 18.9 20 21.2 21.65 25.4 25.85 26.5 28.8
	}
    }

}

proc vfo::ignore {args} {
}

proc vfo::turned {w turns} {
    upvar #0 $w data
    vfo::set-freq $w [expr {$data(frequency)+$turns*$data(turn-resolution)}]
}

proc vfo::set-freq {w hertz} {
    upvar #0 $w data
    set data(frequency) $hertz
    switch $data(display-unit) {
	MHz { set f [expr {$hertz/1e6}] }
	kHz { set f [expr {$hertz/1e3}] }
	Hz { set f $hertz }
    }
    switch $data(display-precision) {
	X { set data(f) [format {%.0f} $f] }
	X.XXX { set data(f) [format {%.3f} $f] }
	X.XXXXXX { set data(f) [format {%.6f} $f] }
	X.XXXXXXXXX { set data(f) [format {%.9f} $f] }
    }
    switch $data(display-unit) {
	MHz { eval $data(frequency-changed) [expr {$data(f)*1e6}] }
	kHz { eval $data(frequency-changed) [expr {$data(f)*1e3}] }
	Hz { eval $data(frequency-changed) $data(f) }
    }
}

proc vfo::unit-changed {w u} {
    upvar #0 $w data
    # preserve the least significant digit by changing precision
    # as much as possible
    switch $u/$data(display-unit-old) {
	Hz/MHz {
	    switch $data(display-precision) {
		X -
		X.XXX -
		X.XXXXXX { set data(display-precision) X }
		X.XXXXXXXXX { set data(display-precision) X.XXX }
	    }
	}
	kHz/MHz - Hz/kHz {
	    # from MHz to kHz, or kHz to Hz
	    switch $data(display-precision) {
		X -
		X.XXX { set data(display-precision) X }
		X.XXXXXX { set data(display-precision) X.XXX }
		X.XXXXXXXXX { set data(display-precision) X.XXXXXX }
	    }
	}
	MHz/MHz - kHz/kHz - Hz/Hz {
	    # no change
	}
	MHz/kHz - kHz/Hz {
	    # from Hz to kHz, or kHz to MHz
	    switch $data(display-precision) {
		X { set data(display-precision) X.XXX }
		X.XXX { set data(display-precision) X.XXXXXX }
		X.XXXXXX -
		X.XXXXXXXXX { set data(display-precision) X.XXXXXXXXX }
	    }
	}
	MHz/Hz {
	    # from Hz to MHz
	    switch $data(display-precision) {
		X { set data(display-precision) X.XXXXXX }
		X.XXX -
		X.XXXXXX -
		X.XXXXXXXXX { set data(display-precision) X.XXXXXXXXX }
	    }
	}
    }
    set data(display-unit-old) $u
    vfo::set-freq $w $data(frequency)
}    

proc vfo::precision-changed {w p} {
    upvar #0 $w data
    vfo::set-freq $w $data(frequency)
}

proc vfo::channel-incr {w inc} {
    upvar #0 $w data
    set l [llength $data(channels)]
    set data(channel) [expr {($data(channel)+$inc+$l) % $l}]
    set-freq $w [expr {int([lindex $data(channels) $data(channel)]*1000000)}]
}

proc vfo::channel-set {w} {
    upvar #0 $w data
    # fix.me - open channel configuration dialog
}

proc vfo::channel-add {w} {
    upvar #0 $w data
    # fix.me - add the current frequency to the channels
}

proc vfo::channel-sub {w} {
    upvar #0 $w data
    # fix.me - remove the current frequency from the channels
}

proc vfo::vfo {w args} {
    upvar #0 $w data
    variable config
    array set data [array get config]
    foreach {name value} $args {
	switch -- $name {
	    -frequency-changed { set data(frequency-changed) $value }
	    default {
		error "unknown option $name"
	    }
	}
    }
    ttk::frame $w
    pack [ttk::label $w.top] -side top
    pack [ttk::label $w.frequency -textvar ${w}(f) -font $data(font)] -in $w.top -side left
    # fix.me - make the font change for ttk::menubutton
    pack [menubutton $w.displayresolution -textvar ${w}(display-unit) -font $data(font) -menu $w.displayresolution.m] -in $w.top -side left
    menu $w.displayresolution.m -tearoff no
    foreach u $data(display-units) {
	$w.displayresolution.m add radiobutton -label $u -variable ${w}(display-unit) -value $u -command [list vfo::unit-changed $w $u]
    }
    $w.displayresolution.m add separator
    foreach p $data(display-precisions) {
	$w.displayresolution.m add radiobutton -label $p -variable ${w}(display-precision) -value $p -command [list vfo::precision-changed $w $p]
    }
    pack [dial::dial $w.dial -radius 100 -rotation [list ::vfo::turned $w]] -side top

    pack [ttk::labelframe $w.channels -text Channels] -side top
    pack [ttk::button $w.up -text + -width 3 -command [list vfo::channel-incr $w 1]] -in $w.channels -side left
    pack [ttk::button $w.down -text - -width 3 -command [list vfo::channel-incr $w -1]] -in $w.channels -side left 
    pack [ttk::button $w.add -text ++ -width 3 -command [list vfo::channel-memo $w]] -in $w.channels -side left
    pack [ttk::button $w.set -text = -width 3 -command [list vfo::channel-set $w]] -in $w.channels -side left

    pack [ttk::labelframe $w.turns -text Resolution] -side top
    foreach r $data(turn-resolutions) {
	pack [ttk::radiobutton $w.turns.x$r -text $r -variable ${w}(turn-resolution) -value $r] -side left
    }
    set-freq $w $data(frequency)
    # fix.me $w should become the command procedure for this megawidget
    return $w
}    
