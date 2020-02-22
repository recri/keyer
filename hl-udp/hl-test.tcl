#!/usr/bin/wish

tk scaling [expr {10*[tk scaling]}]

lappend auto_path ../lib

source ./hl-udp.tcl
package require sdrtcl::hl-jack

array set options {
    -speed 48000
    -lna-db 40
}

namespace eval ::hl {}

# a manually refreshed information string
# probably should just refresh on a timer
snit::widget hl::refresh {
    component lbl
    option -subst -default {}
    option -period -default 2000
    variable string
    constructor {args} {
	$self configure {*}$args
	install lbl as ttk::label $win.lbl -textvariable [myvar string]
	pack $win.lbl -side left -expand true -fill x
	$self refresh
    }
    method refresh {} {
	set string [subst $options(-subst)]
	after $options(-period) [mymethod refresh]
    }
}

snit::widget hl::slider {
    component lbl
    component spn
    component scl
    option -label -default {}
    option -from -default 0
    option -to -default 100
    option -increment -default 1
    option -integer -default 0
    option -hl-udp -default {}
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configure {*}$args
	set value [$self get]
	set ::options($options(-hl-opt)) $value
	install lbl using ttk::label $win.lbl -text $options(-label) -width 10
	install spn using spinbox $win.spn -from $options(-from) -to $options(-to) -increment $options(-increment) \
	    -format %3.0f -width 3 \
	    -textvariable [myvar value] -command [mymethod set]
	install scl using ttk::scale $win.scl -from $options(-from) -to $options(-to) -orient horizontal \
	    -variable [myvar value] -command [mymethod set]
	pack $win.lbl -side left -padx 16
	pack $win.spn -side left -padx 16
	pack $win.scl -side left -padx 16
    }
    method get {} { return [$options(-hl-udp) cget $options(-hl-opt)] }
    method set {{val {}}} {
	if {$options(-integer)} { set value [expr {int($value)}] }
	set ::options($options(-hl-opt)) $value
	$options(-hl-udp) configure $options(-hl-opt) $value
    }
}

snit::widget hl::choice {
    component lbl
    component spn
    option -label -default {}
    option -values -default {}
    option -width -default 6
    option -hl-udp -default {}
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configure {*}$args
	set value [$self get]
	# puts "$self has value $value"
	set ::options($options(-hl-opt)) $value
	install lbl using ttk::label $win.l -text $options(-label) -width 10
	install spn using spinbox $win.p -values $options(-values) -width $options(-width) \
	    -textvariable [myvar value] -command [mymethod set]
	$spn set $value
	pack $win.l $win.p -side left -padx 16
    }
    method get {} { return [$options(-hl-udp) cget $options(-hl-opt)] }
    method set {{val {}}} {
	$options(-hl-udp) configure $options(-hl-opt) $value
	set ::options($options(-hl-opt)) $value
    }
}

snit::widget hl::check {
    component chk
    option -label -default {}
    option -hl-udp -default {}
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configurelist $args
	install chk using ttk::checkbutton $win.c -text $options(-label) -width 16 -variable [myvar value] -command [mymethod set]
	pack $win.c -side left -padx 16
	set value [$self get]
	set ::options($options(-hl-opt)) $value
    }
    method get {} { return [$options(-hl-udp) cget $options(-hl-opt)] }
    method set {{val {}}} { 
	$options(-hl-udp) configure $options(-hl-opt) $value
	set ::options($options(-hl-opt)) $value
    }
}

proc main {argv} {
    foreach {opt val} $argv { 
	switch -- $opt {
	    -jack {
		set ::options(-rx) {hlj send}
		set ::options(-tx) {hlj recv}
	    }
	    default {
		set ::options($opt) $val
	    }
	}
    }

    set row -1

    sdrtcl::hl-udp hlu {*}[array get ::options]
    sdrtcl::hl-jack hlj -i-rx 0 -n-rx [hlu cget -n-rx] -speed [hlu cget -speed]
    hlj activate
    hlj start
    grid [hl::refresh .id -period 2000 \
	      -subst [join {
		  {peer: [hlu cget -peer]}
		  {mac-addr: [hlu cget -mac-addr]}
		  {board-id: [hlu cget -board-id]}
		  {code-version: [hlu cget -code-version]}
		  {serial: [hlu cget -serial]}
	      } {, }]] -row [incr row] -column 0 -columnspan 10 -sticky ew

    grid [hl::refresh .rxstats -period 250 -subst {[hlu stats rx]}] -row [incr row] -column 0 -columnspan 10 -sticky ew
    grid [hl::refresh .txstats -period 250 -subst {[hlu stats tx]}] -row [incr row] -column 0 -columnspan 10 -sticky ew
    grid [hl::refresh .bsstats -period 250 -subst {[hlu stats bs]}] -row [incr row] -column 0 -columnspan 10 -sticky ew

    grid [hl::slider .lna -label {Rx LNA dB} -from -12 -to 48 -increment 1 -integer true \
	      -hl-udp hlu -hl-opt -lna-db] -row [incr row] -column 0 -sticky ew
    grid [hl::slider .lev -label {Tx Level} -from 0 -to 255 -increment 1 -integer 1 \
	      -hl-udp hlu -hl-opt -level] -row [incr row] -column 0 -sticky ew

    grid [hl::check .mx -label {MOX} -hl-udp hlu -hl-opt -mox] -row [incr row] -column 0 -sticky ew
    grid [hl::check .bs -label {Bandscope} -hl-udp hlu -hl-opt -bandscope] -row [incr row] -column 0 -sticky ew
    grid [hl::check .low -label {Low Power T/R} -hl-udp hlu -hl-opt -low-pwr] -row [incr row] -column 0 -sticky ew
    grid [hl::check .pa -label {PA Enable} -hl-udp hlu -hl-opt -pa] -row [incr row] -column 0 -sticky ew
    grid [hl::check .sy -label {Not SYNC} -hl-udp hlu -hl-opt -not-sync] -row [incr row] -column 0 -sticky ew
    grid [hl::check .du -label {Duplex} -hl-udp hlu -hl-opt -duplex] -row [incr row] -column 0 -sticky ew
    
    grid [hl::choice .sp -label {Speed} -values {48000 96000 192000 384000} -hl-udp hlu -hl-opt -speed] -row [incr row] -column 0 -sticky ew
    grid [hl::choice .nr -label {N Rx} -values {1 2 3 4}  -hl-udp hlu -hl-opt -n-rx] -row [incr row] -column 0 -sticky ew

    # -filters -
    # -f-tx -f-rx?
    # -pure-signal
    # -bias-adjust
    # -vna
    # -vna-count
    # -vna-started

    # -hw-key
    # -hw-ptt
    # -overflow
    # -serial
    # -temperature
    # -fwd-power
    # -rev-power
    # -pa-current
    foreach i {0 1 2 3 4 5 6 7 8 9} {
	grid columnconfigure . $i -weight 1
    }
}

main $argv
