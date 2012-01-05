#
# this package provides menus for setting the fft
# parameters for section and spectrogram canvas items
#
# the missing parameters are the ones which determine
# the window into the ongoing sound channel that is
# analysed.
#
package provide params 1.0

namespace eval ::params:: {
    array set values {
	brightness {-100.0 -75.0 -50.0 -25.0 0.0 25.0 50.0 75.0 100.0}
	channel {all left right both 0 1 2 3 4 5 6 7}
	colormap {{}}
	contrast {-100.0 -75.0 -50.0 -25.0 0.0 25.0 50.0 75.0 100.0}
	fftlength {8 16 32 64 128 256 1024 2048 4096}
	gridcolor {{}}
	gridfspacing {0 100 250 500 1000 2000 2500 5000}
	gridtspacing {0 0.1 0.5 1 2 5}
	limit {32767 16383 8191 4095 2047 1023 511 255 127 63 31 15 7 3 1 0}
	maxvalue {0.0 -10.0 -20.0 -30.0 -40.0 -50.0 -60.0 -70.0 -80.0}
	minvalue {0.0 -10.0 -20.0 -30.0 -40.0 -50.0 -60.0 -70.0 -80.0}
	pixelspersecond {1 8 16 24 32 64 128}
	preemphasisfactor {0.0 0.25 0.5 0.75 0.97 1.00}
	subsample {1 2 4 8 12 16 24 32 64 128}
	topfrequency {0.0 2500 5000 7500 10000 15000 20000 25000 30000}
	windowtype {hamming hanning bartlett blackman rectangle}
	winlength {8 16 32 64 128 256 1024 2048 4096}
	zerolevel {true false}
    }
    array set defaults {
	section.fftlength 512
	section.winlength 256
	section.preemphasisfactor 0.0
	section.topfrequency 0.0
	section.channel all
	section.maxvalue 0.0
	section.minvalue -80.0
	section.skip -1
	section.windowtype hamming

	spectrogram.topfrequency 0.0
	spectrogram.channel all
	spectrogram.brightness 0.0
	spectrogram.contrast 0.0
	spectrogram.fftlength 256
	spectrogram.winlength 128
	spectrogram.pixelspersecond 250.0
	spectrogram.preemphasisfactor 0.97
	spectrogram.topfrequency 0.0
	spectrogram.gridtspacing 0.0
	spectrogram.gridfspacing 0
	spectrogram.colormap {}
	spectrogram.gridcolor red
	spectrogram.windowtype hamming

	waveform.pixelspersecond 250.0
	waveform.zerolevel true
	waveform.limit -1.0
	waveform.subsample 1
	waveform.trimstart 0
	waveform.tround 2105221245
    }
}

proc ::params::any-menu {w m cmd widget name} {
    upvar \#0 $w data
    variable values
    variable defaults
    menubutton $m -text $name -menu $m.m
    menu $m.m -tearoff no
    if { ! [info exists data($name)]} {
	if {[info exists defaults($widget.$name)]} {
	    set data($name) $defaults($widget.$name)
	} elseif {[info exists defaults($name)]} {
	    set data($name) $defaults($name)
	} else {
	    set data($name) [lindex $values($name) 0]
	}
	eval $cmd
    }
    foreach len $values($name) {
	$m.m add radiobutton -label $len -variable ${w}($name) -value $len -command $cmd
    }
    return $m
}

