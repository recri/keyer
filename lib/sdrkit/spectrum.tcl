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

package require sdrtcl::jack
package require sdrtcl::spectrum-tap
package require sdrui::tk-spectrum
package require sdrtk::radiomenubutton

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::spectrum {    
    option -name sdr-spectrum
    option -type jack
    option -server default
    option -component {}


    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {}
    option -in-options {
	-period -size -polyphase -result -tap
	-pal -max -min -smooth -multi -zoom -pan
	-mode -freq -lo-freq -cw-freq -carrier-freq
	-low -high
    }
    option -out-options {}

    option -sample-rate 48000

    option -period -default 100 -configuremethod Configure
    option -size -default 1024 -configuremethod TapConfigure
    option -polyphase -default 1 -configuremethod TapConfigure
    option -result -default dB -configuremethod TapConfigure
    option -tap -default {} -configuremethod TapConfigure

    option -pal -default 0 -configuremethod TkConfigure
    option -max -default 0 -configuremethod TkConfigure
    option -min -default -160 -configuremethod TkConfigure
    option -smooth -default false -configuremethod TkConfigure
    option -multi -default 1 -configuremethod TkConfigure
    option -zoom -default 1 -configuremethod TkConfigure
    option -pan -default 0 -configuremethod TkConfigure

    # tuning mode
    option -mode -default CWU -configuremethod TkConfigure
    # tuning
    option -freq -default 7050000 -configuremethod Retune
    option -lo-freq -default 10000 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -carrier-freq -default 7040000 -configuremethod Retune
    # band pass filter
    option -low -default 400 -configuremethod Retune
    option -high -default 800 -configuremethod Retune

    variable data -array {
	tap-deferred-opts {}
	after {}
	frequencies {}
    }

    constructor {args} {
	set options(-server) [from args -server default]
	set options(-sample-rate) [sdrtcl::jack -server $options(-server) sample-rate]
	$self configure {*}$args
    }
    destructor {
	catch {after cancel $data(after)}
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	toplevel .spectrum-$options(-name)
	set data(display) [sdrui::tk-spectrum .spectrum-$options(-name).s {*}[$self TkOptions]]
	pack $data(display) -side top -fill both -expand true
	sdrtcl::spectrum-tap ::sdrkitx::$options(-name) {*}[$self TapOptions]
	set data(after) [after $options(-period) [mymethod Update]]
    }
    method build-ui {} {
	if {$options(-window) eq {none}} return
	set w $options(-window)
	if {$w eq {}} { set pw . } else { set pw $w }

	# no spectrum source tap control
	
	# spectrum fft size control, use scale?
	lassign [list [sdrtype::spec-size cget -values] {}] values labels
	foreach x $values { lappend labels "size $x" }
	sdrtk::radiomenubutton $w.size -defaultvalue $options(-size) -values $values -labels $labels \
	    -variable [myvar options(-size)] -command [mymethod Set -size]
	
	# polyphase spectrum control
	lassign { {1 2 4 8 16 32} {} } values labels
	foreach x $values { lappend labels [expr {$x==1?{no polyphase}:"polyphase $x"}] }
	sdrtk::radiomenubutton $w.polyphase -defaultvalue $options(-polyphase) -values $values -labels $labels \
	    -variable [myvar options(-polyphase)] -command [mymethod Set -polyphase]
	
	# multi-trace spectrum control
	lassign { {1 2 4 6 8 10 12} {} } values labels
	foreach x $values { lappend labels "multi $x" }
	sdrtk::radiomenubutton $w.multi -defaultvalue $options(-multi) -values $values -labels $labels \
	    -variable [myvar options(-multi)] -command [mymethod Set -multi]
	
	# waterfall palette control
	lassign { {0 1 2 3 4 5} {} } values labels
	foreach x $values { lappend labels "palette $x" }
	sdrtk::radiomenubutton $w.palette -defaultvalue $options(-pal) -values $values -labels $labels \
	    -variable [myvar options(-pal)] -command [mymethod Set -pal]
	
	# waterfall/spectrum min dB, use scale?
	lassign { {} {} } values labels
	for {set x 0} {$x >= -80} {incr x -10} { lappend values $x; lappend labels "min $x dB" }
	sdrtk::radiomenubutton $w.min -defaultvalue $options(-min) -values $values -labels $labels \
	    -variable [myvar options(-min)] -command [mymethod Set -min]
	
	# waterfall/spectrum max dB, use scale?
	lassign { {} {} } values labels
	for {set x -80} {$x >= -160} {incr x -10} { lappend values $x; lappend labels "max $x dB" }
	foreach x $values { lappend labels "max $x dB" }
	sdrtk::radiomenubutton $w.max -defaultvalue $options(-max) -values $values -labels $labels \
	    -variable [myvar options(-max)] -command [mymethod Set -max]
	
	# zoom in/out, use scale?
	lassign { {1 2.5 5 10 25 50 100} {} } values labels
	foreach x $values { lappend labels "zoom $x x" }
	sdrtk::radiomenubutton $w.zoom -defaultvalue $options(-zoom) -values $values -labels $labels \
	    -variable [myvar options(-zoom)] -command [mymethod Set -zoom]
	
	# pan left/right
	
	# assemble grid
	grid $w.size $w.polyphase -sticky ew
	grid $w.multi $w.palette -sticky ew
	grid $w.min $w.max -sticky ew
	grid $w.zoom -sticky ew
	grid columnconfigure [winfo parent $w.zoom] 0 -weight 1
	grid columnconfigure [winfo parent $w.zoom] 1 -weight 1
    }
    method is-active {} { return [::sdrkitx::$options(-name) is-active]  }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }
    method FilterOptions {keepers} {
	foreach opt $keepers { lappend opts $opt $options($opt) }
	return $opts
    }
    method TapOptions {} { return [$self FilterOptions {-server -size -polyphase -result}] }
    method TkOptions {} { return [$self FilterOptions {-sample-rate -pal -max -min -smooth -multi -zoom -pan -mode -freq -lo-freq -cw-freq -carrier-freq -low -high}] }
    method Configure {opt val} { set options($opt) $val }
    method TapConfigure {opt val} { lappend data(tap-deferred-opts) $opt $val }
    method TkConfigure {opt val} {
	set options($opt) $val
	.spectrum-$options(-name) configure $opt $val
    }
    method Tap-is-busy {} { return [lindex [::sdrkitx::$options(-name) modified] 1] }
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
	if {[llength $data(frequencies)] != $options(-size)} {
	    $self UpdateFrequencies
	}
	foreach x $data(frequencies) {
	    lappend xy $x $options(-min)
	}
	$data(display) update $xy
	# start the next
	set data(after) [after $options(-period) [mymethod Update]]
    }
    method Update {} {
	if {[$self Tap-is-busy]} {
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
	    $capture configure {*}$config
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if not active
	if { ! [::sdrkitx::$options(-name) is-active]} {
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# capture spectrum and pass to display
	lassign [::sdrkitx::$options(-name) get] frame dB
	binary scan $dB f* dB
	#puts "Update capture got $n bins"
	if {[llength $data(frequencies)] != $options(-size)} {
	    $self UpdateFrequencies
	}
	foreach x $data(frequencies) y [concat [lrange $dB [expr {$options(-size)/2}] end] [lrange $dB 0 [expr {$options(-size)/2-1}]]] {
	    lappend xy $x $y
	}
	#puts "$xy"
	$data(display) update $xy
	
	# start the next
	set data(after) [after $options(-period) [mymethod Update]]
    }
    method Set {opt val} {
	::sdrkitx::$options(-name) configure $opt $val
	set data(label$opt) [format $data(format$opt) $val]
    }
}
