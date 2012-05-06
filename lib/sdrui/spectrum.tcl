#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 

##
## spectrum - spectrum, and waterfall, display
##
package provide sdrui::spectrum 1.0.0

package require Tk
package require snit
package require sdrtcl::jack
package require sdrui::tk-spectrum
package require sdrtcl::spectrum-tap

snit::type sdrui::spectrum-control {
    option -command {}
    option -opts {
	-any-activate
	-any-deactivate
	-any-enable
	-any-disable
	-mode
	-freq
	-lo-freq
	-cw-freq
	-carrier-freq
	-low
	-high
    }
    option -ports {}
    option -methods {}
    option -opt-connect-from {
	{ctl-notify -any-activate -any-activate}
	{ctl-notify -any-deactivate -any-deactivate}
	{ctl-notify -any-enable -any-enable}
	{ctl-notify -any-disable -any-disable}
	{ctl-rxtx-mode -mode -mode}
	{ctl-rxtx-tuner -freq -freq}
	{ctl-rxtx-tuner -lo-freq -lo-freq}
	{ctl-rxtx-tuner -cw-freq -cw-freq}
	{ctl-rxtx-tuner -carrier-freq -carrier-freq}
	{ctl-rxtx-if-bpf -low -low}
	{ctl-rxtx-if-bpf -high -high}
    }
    option -opt-connect-to {}
    # from ctl-notify
    option -any-activate -configuremethod Opt-handler
    option -any-deactivate -configuremethod Opt-handler
    option -any-enable -configuremethod Opt-handler
    option -any-disable -configuremethod Opt-handler
    # from ctl-rxtx-mode
    option -mode -default CWU -type sdrtype::mode -configuremethod Opt-handler
    # from ctl-rxtx-tune
    option -freq -default 7050000 -type sdrtype::hertz -configuremethod Opt-handler
    option -lo-freq -default 10000 -type sdrtype::hertz -configuremethod Opt-handler
    option -cw-freq -default 600 -type sdrtype::hertz -configuremethod Opt-handler
    option -carrier-freq -default 7040000 -type sdrtype::hertz -configuremethod Opt-handler
    # from ctl-rxtx-if-bpf
    option -low -default 400 -configuremethod Opt-handler
    option -high -default 800 -configuremethod Opt-handler

    constructor {args} {
	$self configure {*}$args
	set options(-container) [{*}$options(-command) cget -container]
    }

    destructor {}

    method resolve {} {}
    
    method Opt-handler {opt val} { $options(-container) configure $opt $val }
}

snit::widget sdrui::spectrum {
    hulltype toplevel
    component display
    component capture
    component control

    # imported for here and display
    option -rate -default 48000 -type sdrtype::sample-rate -configuremethod Opt-display

    option -period -default 100 -type sdrtype::milliseconds

    # from here for capture
    option -polyphase -default 1 -type sdrtype::spec-polyphase -configuremethod Opt-capture
    option -size -default 128 -type sdrtype::spec-size -configuremethod Opt-capture
    option -result -default dB -type sdrtype::spec-result -configuremethod Opt-capture
    # from here for display
    option -pal -default 0 -type sdrtype::spec-palette -configuremethod Opt-display
    option -min -default -150 -type sdrtype::decibel -configuremethod Opt-display
    option -max -default -0 -type sdrtype::decibel -configuremethod Opt-display
    option -zoom -default 1 -type sdrtype::zoom -configuremethod Opt-display
    option -pan -default 0 -type sdrtype::pan -configuremethod Opt-display
    option -smooth -default false -type sdrtype::smooth -configuremethod Opt-display
    option -multi -default 1 -type sdrtype::multi -configuremethod Opt-display
    # from ctl-rxtx-mode for display
    option -mode -default CWU -type sdrtype::mode -configuremethod Opt-display
    # from ctl-rxtx-tune for display
    option -freq -default 7050000 -configuremethod Opt-display
    option -lo-freq -default 10000 -configuremethod Opt-display
    option -cw-freq -default 600 -configuremethod Opt-display
    option -carrier-freq -default 7040000 -configuremethod Opt-display
    # from ctl-rxtx-if-bpf for display
    option -low -default 400 -configuremethod Opt-display
    option -high -default 800 -configuremethod Opt-display

    # from ctl-notify
    option -any-activate -configuremethod Opt-any
    option -any-deactivate -configuremethod Opt-any
    option -any-enable -configuremethod Opt-any
    option -any-disable -configuremethod Opt-any

    option -input -default rx-if-spectrum-pre-filt -configuremethod Opt-input

    option -server -default default -readonly true
    option -container -readonly yes
    option -control -readonly yes
    option -enable -default no -type snit::boolean -configuremethod Enable -cgetmethod IsEnabled
    option -activate -default no -type snit::boolean -configuremethod Activate -cgetmethod IsActivated
    
    variable data -array {
	frequencies {}
	capture-options {-polyphase -size -result}
	display-options {-min -max -smooth -multi -center -rate -zoom -pan}
	pairs {}
    }

    constructor {args} {
	#puts "spectrum constructor {$args}"
	set options(-server) [from args -server [::radio cget -server]]
	set options(-rate) [from args -rate [sdrtcl::jack -server $options(-server) sample-rate]] 

	$self configure {*}$args

	install display using sdrui::tk-spectrum $win.s {*}[$self filter-options display]
	install capture using sdrtcl::spectrum-tap ::sdrctlx::spectrum-tap {*}[$self filter-options capture]
	if {[$capture is-active]} { $capture deactivate }
	install control using sdrctl::control ::sdrctlw::spectrum-control -type ctl -prefix spectrum -suffix {} -factory sdrui::spectrum-control -container $self

	pack $win.s -side top -fill both -expand true
	pack [ttk::frame $win.m] -side top
	wm title $win sdrkit:spectrum
	# spectrum selection menu
	# puts "making input selector: -input {$options(-input)}"
	# too early to do this, there aren't any parts to match yet
	pack [ttk::menubutton $win.m.i -textvar [myvar data(input)] -menu $win.m.i.m] -side left
	menu $win.m.i.m -tearoff no
	$win.m.i.m add radiobutton -label none -variable [myvar data(input)] -value none -command [mymethod Opt-input -input {}]
	if {$options(-input) eq {}} { set data(input) none }
	# defer rest of menu until resolve

	# spectrum fft size control
	pack [ttk::menubutton $win.m.size -textvar [myvar data(size)] -menu $win.m.size.m] -side left
	menu $win.m.size.m -tearoff no
	foreach x {64 128 256 512 1024 2048 4096 8192} {
	    set label "size $x"
	    if {$options(-size) == $x} { set data(size) $label }
	    $win.m.size.m add radiobutton -label $label -variable [myvar data(size)] -value $label -command [mymethod configure -size $x]
	}
	
	# polyphase spectrum control
	pack [ttk::menubutton $win.m.s -textvar [myvar data(polyphase)] -menu $win.m.s.m] -side left
	menu $win.m.s.m -tearoff no
	foreach x {1 2 4 8 16 32} {
	    if {$x == 1} {
		set label {no polyphase}
	    } else {
		set label "polyphase $x"
	    }
	    if {$options(-polyphase) == $x} { set data(polyphase) $label }
	    $win.m.s.m add radiobutton -label $label -variable [myvar data(polyphase)] -value $label -command [mymethod configure -polyphase $x]
	}
	
	# multi-trace spectrum control
	pack [ttk::menubutton $win.m.multi -textvar [myvar data(multi)] -menu $win.m.multi.m] -side left
	menu $win.m.multi.m -tearoff no
	foreach p {1 2 4 6 8 10 12} {
	    set label "multi $p"
	    if {$options(-multi) == $p} { set data(multi) $label }
	    $win.m.multi.m add radiobutton -label $label -variable [myvar data(multi)] -value $label -command [mymethod configure -multi $p]
	}

	if {0} {
	    # waterfall palette control
	    pack [ttk::menubutton $win.m.p -textvar [myvar data(pal)] -menu $win.m.p.m] -side left
	    menu $win.m.p.m -tearoff no
	    foreach p {0 1 2 3 4 5} {
		set label "palette $p"
		if {$options(-pal) == $p} { set data(pal) $label }
		$win.m.p.m add radiobutton -label $label -variable [myvar data(pal)] -value $label -command [mymethod configure -pal $p]
	    }
	}

	# waterfall/spectrum min dB
	pack [ttk::menubutton $win.m.min -textvar [myvar data(min)] -menu $win.m.min.m] -side left
	menu $win.m.min.m -tearoff no
	foreach min {-160 -150 -140 -130 -120 -110 -100 -90 -80} {
	    set label "min $min dB"
	    if {$options(-min) == $min} { set data(min) $label }
	    $win.m.min.m add radiobutton -label $label -variable [myvar data(min)] -value $label -command [mymethod configure -min $min]
	}
	
	# waterfall/spectrum max dB
	pack [ttk::menubutton $win.m.max -textvar [myvar data(max)] -menu $win.m.max.m] -side left
	menu $win.m.max.m -tearoff no
	foreach max {0 -10 -20 -30 -40 -50 -60 -70 -80} {
	    set label "max $max dB"
	    if {$options(-max) == $max} { set data(max) $label }
	    $win.m.max.m add radiobutton -label $label -variable [myvar data(max)] -value $label -command [mymethod configure -max $max]
	}
	
	# zoom in/out
	pack [ttk::menubutton $win.m.zoom -textvar [myvar data(zoom)] -menu $win.m.zoom.m] -side left
	menu $win.m.zoom.m -tearoff no
	foreach zoom {1 2.5 5 10 25 50 100} {
	    set label "zoom $zoom x"
	    if {$options(-zoom) == $zoom} { set data(zoom) $label }
	    $win.m.zoom.m add radiobutton -label $label -variable [myvar data(zoom)] -value $label -command [mymethod configure -zoom $zoom]
	}
	
	# scroll/pan
    }

    destructor {
	# note, snit::widgets and snit::widgetadapters do not have a destroy method
	# call tk::destroy $win to destroy them and their widget children
	# the destructor will be called as part of the tk::destroy sequence
	# anything that won't be cleared up as part of the widget hierarchy
	# needs to happen here
	#puts "spectrum destructor called"
	catch { after cancel $data(after) }
	if {$capture ne {}} {
	    #puts "rename $capture {}"
	    rename $capture {}
	}
	if {$control ne {}} {
	    #puts "$control destroy"
	    # note, destroying a snit instance with rename $instance {}
	    # does not call the destructor of the instance
	    $control destroy
	}
    }

    method resolve {} {
	#puts "spectrum resolve"
	foreach i [{*}$options(-control) part-filter *spectrum*] {
	    #puts "spectrum try match $i"
	    if {[regexp {^(rx|tx)-.*spectrum-(.*)$} $i input prefix suffix]} {
		set label $prefix-$suffix
		if {$label eq {tx-tx}} { set label tx }
		#puts "spectrum matched $i reduced to $label"
		$win.m.i.m add radiobutton -label $label -variable [myvar data(input)] -value $label -command [mymethod Opt-input -input $input]
		if {$options(-input) eq $input} { set data(input) $label }
	    }
	}
    }

    method filter-options {target} {
	set new {}
	foreach {name val} [array get options] {
	    if {$name in $data($target-options)} {
		lappend new $name $val
	    }
	}
	return $new
    }
    
    method capture-is-busy {} { return [lindex [$capture modified] 1] }

    method update {} {
	if {[$self capture-is-busy]} {
	    set data(after) [after $options(-period) [mymethod update]]
	}
	if {[$capture is-active]} {
	    lassign [$capture get] frame dB
	    binary scan $dB f* dB
	    set n [llength $dB]
	    if {[llength $data(frequencies)] != $n} {
		set data(frequencies) {}
		set maxf [expr {$options(-rate)/2.0}]
		set minf [expr {-$maxf}]
		set df [expr {double($options(-rate))/$options(-size)}]
		for {set f $minf} {$f < $maxf} {set f [expr {$f+$df}]} {
		    lappend data(frequencies) $f
		}
	    }
	    foreach x $data(frequencies) y [concat [lrange $dB [expr {$n/2}] end] [lrange $dB 0 [expr {$n/2-1}]]] {
		lappend xy $x $y
	    }
	    #puts "$xy"
	    $display update $xy
	    set data(after) [after $options(-period) [mymethod update]]
	}
    }
    
    method Deactivate {} {
	catch {after cancel $data(after)}
	if {[$capture is-active]} { $capture deactivate }
	set data(pairs) {}
    }

    method TryActivate {} {
	set input $options(-input)
	if {$input eq {} ||
	    ! [$options(-control) part-is-active $input]} {
	    $self Deactivate
	    return
	}
	# puts "$input is-active"
	set ports [$capture info ports]
	set pairs {}
	foreach port [$options(-control) part-ports $input] {
	    lappend pairs {*}[$options(-control) port-active-connections-to [list $input $port]]
	}
	# puts "$input active-connections-to $pairs"
	if {$pairs ne $data(pairs)} {
	    if {[llength $pairs] != [llength $ports]} {
		puts "port mismatch between {$pairs} and {$ports}"
		$self Deactivate
		return
	    }
	    if { ! [$capture is-active]} { $capture activate }
	    foreach port $ports pair $pairs old $data(pairs) {
		puts "sdrtcl::jack -server $options(-server) connect [join $pair :] spectrum-tap:$port"
		sdrtcl::jack -server $options(-server) connect [join $pair :] spectrum-tap:$port
		if {$old ne {}} {
		    puts "sdrtcl::jack -server $options(-server) disconnect [join $old :] spectrum-tap:$port"
		    sdrtcl::jack -server $options(-server) disconnect [join $old :] spectrum-tap:$port
		}
	    }
	    set data(pairs) $pairs
	    set data(after) [after $options(-period) [mymethod update]]
	}
    }

    method Opt-display {opt value} {
	set options($opt) $value
	if {$display ne {}} { $display configure $opt $value }
    }

    method Opt-capture {opt value} {
	set options($opt) $value
	if {$capture ne {}} { $capture configure $opt $value }
    }

    method Opt-input {opt input} {
	puts "spectrum configure -input $input"
	set options(-input) $input
	$self TryActivate
    }

    # incoming reports
    method Opt-any {opt val} {
	set options($opt) $val
	$self TryActivate
    }
}    
