# -*- mode: Tcl; tab-width: 8; -*-
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

#
# a spectrum component
#

package provide sdrkit::spectrum 1.0.0

package require Tk
package require snit
package require sdrtcl::spectrum-tap
package require sdrtcl::jack
package require sdrkit
package require sdrkit::common-sdrtcl
package require sdrtk::spectrum-waterfall

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::spectrum {    

    option -name sdr-spectrum
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {}
    option -options {
	-period -size -polyphase -result -tap
	-pal -max -min -automatic -smooth -multi -zoom -pan
	-mode -freq -lo-freq -cw-freq -carrier-freq
	-bpf-low -bpf-high
	-band-low -band-high
    }

    option -sample-rate 48000

    option -period -default 100 -configuremethod Dispatch
    option -size -default 2048 -configuremethod Dispatch
    option -polyphase -default 1 -configuremethod Dispatch
    option -result -default dB -configuremethod Dispatch
    option -tap -default {rx-if-sp2} -configuremethod Dispatch

    option -pal -default 0 -configuremethod Dispatch
    option -max -default 0 -configuremethod Dispatch
    option -min -default -160 -configuremethod Dispatch
    option -automatic -default true -configuremethod Dispatch
    option -smooth -default false -configuremethod Dispatch
    option -multi -default 1 -configuremethod Dispatch
    option -zoom -default 1 -configuremethod Dispatch
    option -pan -default 0 -configuremethod Dispatch

    option -mode -default CWU -configuremethod Dispatch
    option -freq -default 7050000 -configuremethod Dispatch
    option -lo-freq -default 10000 -configuremethod Dispatch
    option -cw-freq -default 600 -configuremethod Dispatch
    option -bpf-low -default 400 -configuremethod Dispatch
    option -bpf-high -default 800 -configuremethod Dispatch
    option -band-low -default {} -configuremethod Dispatch
    option -band-high -default {} -configuremethod Dispatch
    
    # tap - no spectrum source tap control
    # period - no spectrum period control
    # result - no spectrum result control
    # smooth - no smooth control
    option -sub-controls {
	period iscale {-format {Period %d ms} -from 50 -to 1000} 
	size iscale {-format {Size %d} -from 8 -to 4096}
	polyphase iscale {-format {Polyphase %d} -from 1 -to 32}
	smooth radio {-format {Smooth} -values {0 1} -labels {off on}}
	multi iscale {-format {Multi %d} -from 1 -to 32}
	pal iscale {-format {Palette %d} -from 0 -to 9}
	min iscale {-format {Min %d dBFS} -from -160 -to 50}
	max iscale {-format {Max %d dBFS} -from -160 -to 50}
	zoom scale {-format {Zoom %.2f} -from 0.5 -to 100}
	pan iscale {-format {Pan %d} -from -20000 -to 20000}
    }

    variable data -array {
	tap-deferred-opts {}
	after {}
	frequencies {}
	tap-options {-server -size -polyphase -result}
	tk-options {-sample-rate -pal -max -min -smooth -multi -zoom -pan}
	retune-options {-mode -freq -lo-freq -cw-freq -carrier-freq -bpf-low -bpf-high}
    }

    component common
    delegate method * to common

    constructor {args} {
	set options(-server) [from args -server default]
	set options(-sample-rate) [sdrtcl::jack -server $options(-server) sample-rate]
	$self BuildDispatchTable
	$self configure {*}$args
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
    }
    destructor {
	# if {$::sdrkit::verbose(destroy)} { puts "$self destroy" }
	catch {after cancel $data(after)}
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
	#if {$::sdrkit::verbose(destroy)} { puts "$self destroy, completed" }
    }
    method port-complement {port} { return {} }
    method build-parts {w} {
	toplevel .spectrum-$options(-name)
	set data(display) [sdrtk::spectrum-waterfall .spectrum-$options(-name).s -width 1024 {*}[$self TkOptions] -command [mymethod Set]]
	pack $data(display) -side top -fill both -expand true
	sdrtcl::spectrum-tap ::sdrkitx::$options(-name) {*}[$self TapOptions]
	set data(after) [after $options(-period) [mymethod Update]]
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
    method connect-tap {tap} {
	set taps [$options(-component) part-filter *$tap]
	if {[llength $taps] == 1} {
	    set name1 [lindex $taps 0]
	    set name2 $options(-name)
	    foreach p1 [$options(-component) out-ports $name1] p2 [$options(-component) in-ports $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	} else {
	    error "multiple taps match $tap: $taps"
	}
    }
    method disconnect-tap {tap} {
	set taps [$options(-component) part-filter *$tap]
	if {[llength $taps] == 1} {
	    set name1 [lindex $taps 0]
	    set name2 $options(-name)
	    foreach p1 [$options(-component) out-ports $name1] p2 [$options(-component) in-ports $name2] {
		$options(-component) disconnect-ports $name1 $p1 $name2 $p2
	    }
	} else {
	    error "multiple taps match $tap: $taps"
	}
    }
    method resolve {} {
	$self connect-tap $options(-tap)
    }
    method Set {opt val} { $options(-component) report $opt $val }
    method FilterOptions {keepers} { foreach opt $keepers { lappend opts $opt $options($opt) }; return $opts }
    method TapOptions {} { return [$self FilterOptions $data(tap-options)] }
    method TkOptions {} { return [$self FilterOptions $data(tk-options)] }
    method RetuneOptions {} { return [$self FilterOptions $data(return-options)] }

    method BuildDispatchTable {} {
	foreach {opts handler} [list \
				    $data(tap-options) [mymethod TapConfigure] \
				    $data(tk-options) [mymethod TkConfigure] \
				    $data(retune-options) [mymethod RetuneConfigure] ] {
	    foreach opt $opts {
		set data(Dispatch$opt) $handler
	    }
	}
    }
    method Dispatch {opt val} {
	set old $options($opt)
	set options($opt) [$self Constrain $opt $val]
	if {[info exists data(Dispatch$opt)]} {
	    {*}$data(Dispatch$opt) $opt $options($opt)
	} else {
	    switch -- $opt {
		-tap {
		    if {$old ne $options(-tap)} {
			$self connect-tap $options(-tap)
			$self disconnect-tap $old
		    }
		}
	    }
	}
    }
    method TapConfigure {opt val} {
	lappend data(tap-deferred-opts) $opt $options($opt)
    }
    method TkConfigure {opt val} {
	$data(display) configure $opt $options($opt)
    }
    method RetuneConfigure {opt val} {
	switch $options(-mode) {
	    CWU { set options(-tuned-freq) [expr {$options(-lo-freq)+$options(-cw-freq)}] }
	    CWL { set options(-tuned-freq) [expr {$options(-lo-freq)-$options(-cw-freq)}] }
	    default { set options(-tuned-freq) $options(-lo-freq) }
	}
	set options(-center-freq) [expr {$options(-freq)-$options(-tuned-freq)}]
	set options(-filter-low) [expr {$options(-lo-freq)+$options(-bpf-low)}]
	set options(-filter-high) [expr {$options(-lo-freq)+$options(-bpf-high)}]
	set opts {}
	foreach opt {-center-freq -tuned-freq -filter-low -filter-high} {
	    if {[$data(display) cget $opt] != $options($opt)} { lappend opts $opt $options($opt) }
	}
	if {$opts ne {}} { $data(display) configure {*}$opts }
    }

    method UpdateFrequencies {} {
	#puts "recomputing frequencies for length $n from [llength $data(frequencies)]"
	set data(frequencies) {}
	set maxf [expr {$options(-sample-rate)/2.0}]
	set minf [expr {-$maxf}]
	set df [expr {double($options(-sample-rate))/$options(-size)}]
	for {set i 0} {$i < $options(-size)} {incr i} {
	    lappend data(frequencies) [expr {$minf+$i*$df}]
	}
	#puts "recomputed [llength $data(frequencies)] frequencies"
    }
    method BlankUpdate {} {
	if {[llength $data(frequencies)] != $options(-size)} { $self UpdateFrequencies }
	foreach x $data(frequencies) { lappend xy $x $options(-min) }
	if { ! [winfo exists $data(display)]} {
	    unset data(after)
	} else {
	    $data(display) update $xy
	    # start the next
	    set data(after) [after $options(-period) [mymethod Update]]
	}
    }
    method Update {} {
	if {[$self is-busy]} {
	    # if busy, then supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# handle configuration
	if {$data(tap-deferred-opts) ne {}} {
	    set config $data(tap-deferred-opts)
	    set data(tap-deferred-opts) {}
	    #puts "Update configure $config"
	    ::sdrkitx::$options(-name) configure {*}$config
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if not active
	if { ! [$self is-active]} {
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if {[incr data(nspectrum)] == 1} { puts [join [::sdrkitx::$options(-name) configure] \n] }
	# capture spectrum and pass to display
	lassign [::sdrkitx::$options(-name) get] frame dB
	binary scan $dB f* dB
	#puts "Update capture got $n bins"
	if {[llength $data(frequencies)] != $options(-size)} {
	    $self UpdateFrequencies
	}
	set n [llength $dB]
	if {$n != $options(-size)} {
	    $self BlankUpdate
	    puts "received $n spectrum values instead of $options(-size)"
	    return
	}
	set dB [concat [lrange $dB [expr {$n/2}] end] [lrange $dB 0 [expr {($n/2)-1}]]]
	foreach x $data(frequencies) y $dB {
	    lappend xy $x $y
	}
	#puts "$xy"
	if { ! [winfo exists $data(display)]} {
	    unset data(after)
	} else {
	    $data(display) update $xy
	    # start the next
	    set data(after) [after $options(-period) [mymethod Update]]
	}
    }
}
