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
# a signal generator
# some oscillators and some noise
#

package provide sdrapp::signal-generator 1.0.0

package require snit

package require sdrdsp::signal-generator-control
package require sdrdsp::block

namespace eval sdrdsp {}

snit::type sdrdsp::signal-generator {
    component control
    component sg
    component ui
    
    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -ui-type {command-line}

    constructor {args} {
	$self configure {*}$args
	install control using ::sdrdsp::signal-generator-control %AUTO% -container $self
	set options(-control) $control
	install sg using ::sdrdsp::sg %AUTO% -container $self
	if {$options(-ui)} {
	    package require sdrdsp::signal-generator-ui-$options(-ui-type)
	    install ui using ::sdrdsp::radio-ui-$options(-ui-type) %AUTO% -container $self
	}
    }

    destructor {
	catch {$ui destroy}
	catch {$sg destroy}
	catch {$control destroy}
    }

    method repl {} {
	if {$ui ne {}} { $ui repl }
    }
}

proc sdrapp::sg {name args} {
    set seq {sdrapp::sg-source sdrapp::sg-gain}
    return [sdrdsp::block $name -type sequence -suffix sg -sequence $seq {*}$args]    
}
proc sdrapp::sg-source {name args} {
    set par {sdrapp::sg-osc1 sdrapp::sg-osc2 sdrdsp::comp-noise sdrdsp::comp-iq-noise}
    return [sdrdsp::block $name -type parallel -suffix src -parallel $par {*}$args]
}
proc sdrapp::sg-osc1 {name args} {
    set seq {sdrdsp::comp-oscillator}
    return [sdrdsp::block $name -type jack -suffix osc1 -factory sdrkit::oscillator -require sdrkit::oscillator {*}$args]
}
proc sdrdsp::sg-osc1 {name args} {
    return [sdrdsp::block $name -type jack -suffix osc2 -factory sdrkit::oscillator -require sdrkit::oscillator {*}$args]
}

if {0} {
    # this will be enable/disable
    proc set-mute {mod out args} {
	#puts "set-mute $mod {$args}"
	if {$::data($mod-unmute)} {
	    foreach iq {i q} {
		jack connect $out:out_$iq signal-generator:in_$iq
	    }
	} else {
	    foreach iq {i q} {
		jack disconnect $out:out_$iq signal-generator:in_$iq
	    }
	}
    }
    proc set-gain {osc v} {
	$osc-gain configure -gain $v
	set ::data($osc-gain-label) [format %.2f $v]
    }
    
    proc set-freq {osc v} {
	if {$v == 0} { set v 0.1 }
	$osc configure -freq $v
	set ::data($osc-freq-label) [format %.2f $v]
    }
    
    proc set-noise {noise v} {
	$noise configure -level $v
	set ::data($noise-noise-label) [format %.2f $v]
    }
    
    proc set-master-gain {v} {
	signal-generator configure -gain $v
	set ::data(master-gain-label) [format %.2f $v]
    }
    
    proc shutdown {w} {
	if {$w eq {.}} {
	    foreach client $::data(clients-to-cleanup) {
		rename $client {}
	    }
	}
    }
    
    proc start-client {module name} {
	$module $name -server $::data(server)
	lappend ::data(clients-to-cleanup) $name
    }
    
    proc main {argv} {
	foreach {option value} $argv {
	    switch -- $option {
		-s - -server - --server { set ::data(server) $value }
		-l - -length - --length { set ::data(length) $value }
		-f - -freq - --freq - -frequency - --frequency { set ::data(freq) $value }
		-min-freq - --min-freq { set ::data(min-freq) $value }
		-max-freq - --max-freq { set ::data(max-freq) $value }
		-g - -gain - --gain { set ::data(gain) $value }
		-min-gain - --min-gain { set ::data(min-gain) $value }
		-max-gain - --max-gain { set ::data(max-gain) $value }
		default { error "unknown option \"$option\"" }
	    }
	}
	
	start-client sdrkit::jack-client jack
	if {$::data(max-freq) > [jack sample-rate]/2} {
	    set ::data(max-freq) [expr {[jack sample-rate]/2.01}]
	    set ::data(min-freq) [expr {-$::data(max-freq)}]
	}
	
	wm title . sdrkit:signal-generator
	
	start-client sdrkit::gain signal-generator
	signal-generator configure -gain 0.0
	
	set row 0
	foreach i {0 1 2 3} {
	    start-client sdrkit::oscillator-zd osc$i
	    start-client sdrkit::gain osc$i-gain
	    foreach iq {i q} { jack connect osc$i:out_$iq osc$i-gain:in_$iq }
	    set ::data(osc$i-gain) $::data(gain)
	    set ::data(osc$i-freq) $::data(freq)
	    set ::data(osc$i-unmute) 0
	    set-gain osc$i $::data(osc$i-gain)
	    set-freq osc$i $::data(osc$i-freq)
	    grid [ttk::frame .b$row] -row $row -column 0 -columnspan 3
	    pack [ttk::label .b$row.l -text "Oscillator $i"] -side left
	    pack [ttk::checkbutton .b$row.e -text {enabled} -variable ::data(osc$i-unmute) -command [list set-mute osc$i osc$i-gain]] -side left
	    incr row
	    grid [ttk::label .b$row-gain-l -textvar ::data(osc$i-gain-label) -width 10 -anchor e] -row $row -column 0
	    grid [ttk::label .b$row-gain-u -text dB] -row $row -column 1
	    grid [ttk::scale .b$row-gain-s -from $::data(max-gain) -to $::data(min-gain) -command [list set-gain osc$i] -variable ::data(osc$i-gain) -length $::data(length)] \
		-row $row -column 2 -sticky ew
	    incr row
	    grid [ttk::label .b$row-freq-l -textvar ::data(osc$i-freq-label) -width 10 -anchor e] -row $row -column 0
	    grid [ttk::label .b$row-freq-u -text Hz] -row $row -column 1
	    grid [ttk::scale .b$row-freq-s -from $::data(min-freq) -to $::data(max-freq) -command [list set-freq osc$i] -variable ::data(osc$i-freq) -length $::data(length)] \
		-row $row -column 2 -sticky ew
	    incr row
	}
	
	foreach i {0 1} f {sdrkit::noise sdrkit::iq-noise} l {Noise {IQ Noise}} {
	    start-client $f noise$i
	    set ::data(noise$i-noise) $::data(noise)
	    set ::data(noise$i-unmute) 0
	    set-noise noise$i $::data(noise$i-noise)
	    grid [ttk::frame .b$row] -row $row -column 0 -columnspan 3
	    pack [ttk::label .b$row.l -text $l] -side left
	    pack [ttk::checkbutton .b$row.e -text enabled -variable ::data(noise$i-unmute) -command [list set-mute noise$i noise$i]] -side left
	    incr row
	    grid [ttk::label .b$row-noise-l -textvar ::data(noise$i-noise-label) -width 10 -anchor e] -row $row -column 0
	    grid [ttk::label .b$row-noise-u -text dB] -row $row -column 1
	    grid [ttk::scale .b$row-noise-s -from $::data(max-gain) -to $::data(min-gain) -command [list set-noise noise$i] -variable ::data(noise$i-noise) -length $::data(length)] \
		-row $row -column 2 -sticky ew
	    incr row
	}
	grid [ttk::label .b$row -text "Master Gain"] -row $row -column 0 -columnspan 3
	incr row
	grid [ttk::label .b$row-gain-l -textvar ::data(master-gain-label) -width 10 -anchor e] -row $row -column 0
	grid [ttk::label .b$row-gain-u -text dB] -row $row -column 1
	grid [ttk::scale .b$row-gain-s -from $::data(max-gain) -to $::data(min-gain) -command set-master-gain -variable ::data(master-gain) -length $::data(length)] \
	    -row $row -column 2 -sticky ew
	
	grid columnconfigure . 2 -weight 100
	
	#foreach i {0 1 2 3} { set ::data(osc$i-unmute) 1 }
	#foreach i {0 1} { set ::data(noise$i-unmute) 1 }
	
	bind . <Destroy> [list shutdown %W]
    }
}