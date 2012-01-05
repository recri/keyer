#
# wrap the snack audio command
# need to add variable traces on optionMenues
# so selections can be passed back to snack
#
package provide audio 1.0

namespace eval ::audio:: {
    array set data {
	inputRate 22050
	outputRate 22050
    }
}

proc audio-page {w} {
    upvar \#0 ::audio::data data

    pack [frame $w.g] -side top

    pack [label $w.g.al -text {Input: Device}] -side left
    #set data(selectInput) [::snack::audio selectInput]
    set m [eval tk_optionMenu $w.g.ao ::audio::data(inputDevice) [::snack::audio inputDevices] none]
    pack $w.g.ao -side left

    pack [label $w.g.bl -text {Gain}] -side left
    set data(record_gain) [::snack::audio record_gain]
    pack [scale $w.g.bs -orient horizontal -from 0 -to 100 -variable ::audio::data(record_gain) \
	      -command {audio-set record_gain}] -side left
    
    pack [label $w.g.cl -text {Rate}] -side left
    set m [eval tk_optionMenu $w.g.co ::audio::data(inputRate) [::snack::audio rates]]
    pack $w.g.co -side left

    pack [label $w.g.dl -text {Encoding}] -side left
    set m [eval tk_optionMenu $w.g.do ::audio::data(inputEncoding) [::snack::audio encodings]]
    pack $w.g.do -side left

    pack [label $w.g.el -text {Channels}] -side left
    set m [tk_optionMenu $w.g.eo ::audio::data(inputChannels) 1 2]
    pack $w.g.eo -side left
	   
    pack [frame $w.h] -side top

    pack [label $w.h.al -text {Output: Device}] -side left
    #set data(output) [::snack::audio selectOutput]
    set m [eval tk_optionMenu $w.h.ao ::audio::data(outputDevice) [::snack::audio outputDevices] none]
    pack $w.h.ao -side left

    pack [label $w.h.bl -text {Gain}] -side left
    set data(play_gain) [::snack::audio play_gain]
    pack [scale $w.h.bs -orient horizontal -from 0 -to 100 -variable ::audio::data(play_gain) \
	      -command {audio-set play_gain}] -side left
    
    pack [label $w.h.cl -text {Rate}] -side left
    set m [eval tk_optionMenu $w.h.co ::audio::data(outputRate) [::snack::audio rates]]
    pack $w.h.co -side left

    pack [label $w.h.dl -text {Encoding}] -side left
    set m [eval tk_optionMenu $w.h.do ::audio::data(outputEncoding) [::snack::audio encodings]]
    pack $w.h.do -side left

    pack [label $w.h.el -text {Channels}] -side left
    set m [tk_optionMenu $w.h.eo ::audio::data(outputChannels) 1 2]
    pack $w.h.eo -side left
	   
    pack [frame $w.i] -side top
    
    pack [label $w.i.al -text {Play Latency}] -side left
    set data(playLatency) [::snack::audio playLatency]
    pack [scale $w.i.as -orient horizontal -from 0 -to 5000 -variable ::audio::data(playLatency) \
	      -command {audio-set playLatency}] -side left

    pack [label $w.i.bl -text {Output Scale}] -side left
    set data(scaling) [::snack::audio scaling]
    pack [scale $w.i.bs -orient horizontal -from 0.0 -to 2.0 -resolution 0.05 -variable ::audio::data(scaling) \
	      -command {audio-set scaling}] -side left


    pack [frame $w.j] -side top
    pack [button $w.j.start -text start -command [list ::audio::start $w]] -side left
    pack [button $w.j.stop -text stop -command [list ::audio::stop $w] -state disabled] -side left
}

proc audio-raise args { }
proc audio-leave args { return 1 }

proc audio-get {var} {
    upvar \#0 ::audio::data data
    return $data($var)
}

proc audio-set {var args} {
    upvar \#0 ::audio::data data
    ::snack::audio $var $data($var)
    switch $var {
	selectInput {
	    set data(record_gain) [::snack::audio record_gain]
	}
	selectOutput {
	    set data(play_gain) [::snack::audio play_gain]
	}
    }
}

proc ::audio::start {w} {
    variable data
    $w.j.start configure -state disabled
    $w.j.stop configure -state normal
    switch $data(inputDevice) {
	none {
	    error "no input device specified"
	}
	file {
	    # find the file and load it
	}
	default {
	    set data(record) [::snack::sound \
				  -rate [audio-get inputRate] \
				  -encoding [audio-get inputEncoding] \
				  -channels [audio-get inputChannels] \
				  -changecommand ::audio::inputUpdate]
	    $data(record) record
	}
    }
    switch $data(outputDevice) {
	none {
	    # ignore
	}
	file {
	    # find the file and write into it
	}
	default {
	    set data(play) [::snack::sound -rate [audio-get outputRate] \
				-encoding [audio-get outputEncoding] \
				-channels [audio-get outputChannels]]
	    catch {unset data(is-playing)}
	}
    }
}

proc ::audio::inputUpdate {key} {
    variable data
    #puts "::audio::update $key - length recording = [$data(record) length] samples"
    switch $key {
	More {
	    outputFillQueue $data(record)
	    $data(record) cut 0 [expr {[$data(record) length]-1}]
	}
	New {
	}
	Destroy {
	}
    }
}

proc ::audio::outputFillQueue {sound} {
    variable data
    $data(play) concatenate $sound
    if { ! [info exists data(is-playing)] && [$data(play) length] >= 512} {
	set data(is-playing) 1
	$data(play) play -blocking 0
    }
}

proc ::audio::stop {w} {
    variable data
    $w.j.start configure -state normal
    $w.j.stop configure -state disabled
    puts "\$data(record) destroy"
    catch {$data(record) destroy}
    catch {unset data(record)}
    catch {$data(play) destroy}
    catch {unset data(play)}
}

proc audio-active {} {
    upvar \#0 ::audio::data data
    return [info exists data(record)]
}

proc audio-sound {} {
    upvar \#0 ::audio::data data
    return $data(record)
}
