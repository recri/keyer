#
# this should be a simple sliding fft
#
package provide pc-radio 1.0
foreach pkg {audio sm5bsz-params sfftw} {
    package require $pkg
}

namespace eval ::pc-radio:: {
    array set data { }
    array set params { }
    set PI [expr {atan2(0,-1)}]
}

proc pc-radio-page {w} { ::pc-radio::page $w }
proc pc-radio-raise args { ::pc-radio::raise }
proc pc-radio-leave args { return [::pc-radio::leave] }

proc ::pc-radio::page {w} {
    variable data
    set data(w) $w

    #
    # fft1 averaging
    #
    set data(fft1_avg) 35
    pack [LabelFrame $w.fft1avg -text {spectrum average}] -side top
    pack [scale $w.fft1avg.s -orient horizontal -from 0 -to 100 -variable ::pc-radio::data(fft1_avg)] -side left
    #
    # waterfall averaging
    #
    set data(wf1_avg) 10
    pack [LabelFrame $w.wf1avg -text {waterfall average}] -side top
    pack [scale $w.wf1avg.s -orient horizontal -from 0 -to 100 -variable ::pc-radio::data(wf1_avg)] -side left
    #
    # waterfall zero
    #
    set data(wf1_zero) 40
    pack [LabelFrame $w.wf1zero -text {waterfall zero}] -side top
    pack [scale $w.wf1zero.s -orient horizontal -from 0 -to 100 -variable ::pc-radio::data(wf1_zero)] -side left
    #
    # waterfall gain
    #
    set data(wf1_gain) 0.40
    pack [LabelFrame $w.wf1gain -text {waterfall gain}] -side top
    pack [scale $w.wf1gain.s -orient horizontal -from 0.00 -to 1.00 -resolution 0.01 -variable ::pc-radio::data(wf1_gain)] -side left
    
    #
    # waterfall display from first fft
    # image photo may not be fast enough
    #
    image create photo ::pc-radio::wf1 -width 600 -height 200
    pack [label $w.wf1 -image ::pc-radio::wf1] -side top

    #
    # spectrum display from first fft
    # canvas may not be fast enough
    #
    pack [canvas $w.sp1 -width 600 -height 200] -side top
    
    #
    # ...
    #
    pack [frame $w.b] -side top
    pack [button $w.b.start -text start -command ::pc-radio::start] -side left
    pack [button $w.b.stop -text stop -command ::pc-radio::stop -state disabled] -side left
}

proc ::pc-radio::raise {} {
}
proc ::pc-radio::leave {} {
    return 1
}

proc ::pc-radio::start {} {
    variable data
    variable params
    set w $data(w)
    # update button state
    $w.b.start configure -state disabled
    set data(state) 1
    # fetch parameter settings
    array set params [sm5bsz-params-get]
    # create input sound
    set data(record) [::snack::sound \
			  -rate [audio-get inputRate] \
			  -encoding [audio-get inputEncoding] \
			  -channels [audio-get inputChannels] \
			  -changecommand ::pc-radio::inputUpdate]
    # create fft1 input sound
    set data(fft1_input) [::snack::sound \
			      -rate [audio-get inputRate] \
			  -encoding [audio-get inputEncoding] \
			  -channels [audio-get inputChannels] \
			  -changecommand ::pc-radio::fft1Update]
    # make fft1 input and output windows
    make-sin-n-windows $params(fft1_size) $params(FIRST_FFT_SINPOW) data(fft1_input_window) data(fft1_output_window)

    # make fft1 plan
    if {[file exists fftwisdom]} {
	set fp [open fftwisdom]
	set wisdom [read $fp]
	close $fp
	::sfftw::fftw_import_wisdom $wisdom
    }
    set data(fft1_plan_forward) [::sfftw::rfftw_create_plan $params(fft1_size) $::sfftw::FFTW_FORWARD \
				     [expr {$::sfftw::FFTW_MEASURE|$::sfftw::FFTW_USE_WISDOM}]]
    set data(fft1_plan_backward) [::sfftw::rfftw_create_plan $params(fft1_size) $::sfftw::FFTW_BACKWARD \
				      [expr {$::sfftw::FFTW_MEASURE|$::sfftw::FFTW_USE_WISDOM}]]
    set fp [open fftwisdom w]
    puts $fp [::sfftw::fftw_export_wisdom]
    close $fp

    # create output sound
    set data(play) [::snack::sound -rate [audio-get outputRate] \
			-encoding [audio-get outputEncoding] \
			-channels [audio-get outputChannels]]
    # mark output as not active
    catch {unset data(is-playing)}
    # start the recording
    $data(record) record
    # update button state
    $w.b.stop configure -state normal
    # create line for spectrum update
    $w.sp1 create line 0 0 600 0 -tags spectrum
}

proc ::pc-radio::stop {} {
    variable data
    set w $data(w)
    $w.b.start configure -state normal
    $w.b.stop configure -state disabled
    set data(state) 0
    $data(record) stop
}

proc ::pc-radio::inputUpdate {key} {
    variable data
    set w $data(w)
    switch $data(state) {
	0 {
	    if {[info exists data(record)]} {
		$data(record) flush
	    }
	    if {[info exists data(fft1_input)]} {
		$data(fft1_input) flush
	    }
	}
	1 {
	    switch $key {
		More {
		    if {[info exists data(record)]} {
			$data(fft1_input) concatenate $data(record)
			$data(record) cut 0 [expr {[$data(record) length]-1}]
		    }
		}
		New {
		}
		Destroy {
		}
	    }
	}
    }
}

proc ::pc-radio::fft1Update {key} {
    variable data
    variable params
    set w $data(w)
    switch $key {
	More {
	    while {[$data(fft1_input) length] >= $params(fft1_size)} {
		# fetch buffer of samples for fft
		set buff1 [$data(fft1_input) data -start 0 -end $params(fft1_size) -fileformat RAW]

		# trim off the samples which are now history
		$data(fft1_input) cut 0 [expr {$params(fft1_interleave_points)-1}]

		# window buffer into float format
		set sw {}
		binary scan $buff1 s* buff1
		#puts "buff1 $buff1"
		foreach s $buff1 w $data(fft1_input_window) {
		    lappend sw [expr {$s*$w}]
		}
		#puts "wind1 $sw"
		# forward fft
		set buff1 [binary format f* $sw]
		set buff2 [binary format x[expr {$params(fft1_size)*4}]]
		#puts "fft1_size = $params(fft1_size), buff1_size = [string length $buff1], buff2_size = [string length $buff2]"
		::sfftw::rfftw_one $data(fft1_plan_forward) buff1 buff2

		# compute power spectrum for first display
		binary scan $buff2 f* s
		set r [lindex $s 0]
		set p [expr {$r*$r}]; # dc component
		set N [llength $s]
		for {set k 1} {$k < ($N+1)/2} {incr k} {
		    # k < N/2 rounded up
		    set r [lindex $s $k]
		    set i [lindex $s [expr {$N-$k}]]
		    lappend p [expr {$r*$r + $i*$i}]
		}
		if {($N % 2) == 0} {
		    # N is even
		    set i [lindex $s [expr {$N/2}]]
		    lappend p [expr {$i*$i}];	# Nyquist freq.
		}
		
		# average spectrum for first power spectrum display
		lappend data(fft1_spectra) $p
		while {[llength $data(fft1_spectra)] >= $data(fft1_avg)} {
		    spectraUpdate
		}

		# average spectrum for first waterfall display
		lappend data(wf1_spectra) $p
		while {[llength $data(wf1_spectra)] >= $data(wf1_spectra)} {
		    waterfallUpdate
		}

		# agc / noise floor calibration

		# reverse fft
		::sfftw::rfftw_one $data(fft1_plan_backward) buff2 buff1

		# unwindow buffer into float format
		set sw {}
		binary scan $buff1 f* buff1
		foreach s $buff1 w $data(fft1_output_window) {
		    lappend sw [expr {$s*$w}]
		}
		#puts "wind2 $sw"
		# merge samples together
	    }
	}
	New {
	}
	Destroy {
	}
    }
}

#
# convert the collection of raw transform outputs at data(fft1_transforms)
# into an average power spectrum, display it in the spectrum window, and
# display it in the waterfall graph
#
proc ::pc-radio::spectraUpdate {} {
    variable data
    variable params
    set w $data(w)
    # compute average power spectrum
    set np $data(fft1_avg)
    foreach {ps data(fft1_spectra)} [average-spectra $np $data(fft1_spectra)] break
    #puts "averaged $np spectra to $ps"
    set x 0
    set dx [expr {600/($params(fft1_size)/2)}]
    set miny 10000
    set maxy -10000
    foreach j $ps {
	set y 0
	catch {
	    set y [expr {-20*log10($j)}]
	}
	lappend xy $x [expr {100+$y}]
	set x [expr {$x+$dx}]
	if {$y > $maxy} { set maxy $y }
	if {$y < $miny} { set miny $y }
    }
    eval $w.sp1 coords spectrum $xy
    ::update
    puts "y $miny .. $maxy"
}

proc ::pc-radio::waterfallUpdate {} {
    variable data
    variable params
    set w $data(w)
    # compute average power spectrum
    set np $data(wf1_avg)
    foreach {ps data(wf1_spectra)} [average-spectra $np $data(wf1_spectra)] break
    return
    #puts "averaged $np spectra to $ps"
    set x 0
    set dx [expr {600/($params(fft1_size)/2)}]
    set miny 10000
    set maxy -10000
    foreach j $ps {
	set y 0
	catch {
	    set y [expr {-20*log10($j)}]
	}
	lappend xy $x [expr {100+$y}]
	set x [expr {$x+$dx}]
	if {$y > $maxy} { set maxy $y }
	if {$y < $miny} { set miny $y }
    }
    eval $w.sp1 coords spectrum $xy
    ::update
    puts "y $miny .. $maxy"
}

proc ::pc-radio::average-spectra {np from} {
    set myp [lrange $from 0 $np]
    set from [lrange $from $np end]
    foreach p $myp {
	set newps {}
	if {[info exists ps]} {
	    foreach i $p j $ps {
		lappend newps [expr {$i/$np+$j}]
	    }
	} else {
	    foreach i $p {
		lappend newps [expr {$i/$np}]
	    }
	}
	set ps $newps
    }
    return [list $ps $from]
}

proc ::pc-radio::outputFillQueue {sound} {
    variable data
    set w $data(w)
    $data(play) concatenate $sound
    if { ! [info exists data(is-playing)] && [$data(play) length] >= 512} {
	set data(is-playing) 1
	$data(play) play -blocking 0
    }
}

proc ::pc-radio::compare-buff-to-samples {buff samp} {
    binary scan $buff s* buff
    set n [llength $buff]
    set max -32000
    set min  32000
    for {set i 0} {$i < $n} {incr i} {
	set bi [lindex $buff $i]
	set si [$samp sample $i]
	if {$bi != $si} {
	    puts "buff and sample differ at $i: $bi and $si"
	}
	if {$bi > $max} { set max $bi }
	if {$bi < $min} { set min $bi }
    }
    puts "compared $n samples max $max min $min"
}

#
# this makes the sin^n window and also normalizes
# what is assumed to be 16 bit signed input data
# to 1 .. -1
proc ::pc-radio::make-sin-n-windows {size n input output}  {
    upvar $input idata
    upvar $output odata
    set idata {}
    set odata {}
    variable PI
    set x [expr {0.5*$PI/$size}]
    for {set i 0} {$i < $size} {incr i} {
	set sinn [expr {pow(sin($x),$n)}]
	lappend idata [expr {$sinn/32768}]
	lappend odata [expr {32768/$sinn}]
	set x [expr {$x+$PI/$size}]
    }
    #puts "make-sin-n-windows $size $n $input $output\n$idata\n$odata"
}