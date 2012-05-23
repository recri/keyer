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

    option -mode -default CWU -configuremethod Retune
    option -freq -default 7050000 -configuremethod Retune
    option -lo-freq -default 10000 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -carrier-freq -default 7040000 -configuremethod Retune
    option -low -default 400 -configuremethod Retune
    option -high -default 800 -configuremethod Retune
    
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
	min iscale {-format {Min %d dBFS} -from -160 -to -80}
	max iscale {-format {Max %d dBFS} -from -80 -to 0}
	zoom scale {-format {Zoom %.2f} -from 0.5 -to 100}
	pan iscale {-format {Pan %d} -from -20000 -to 20000}
    }

    variable data -array {
	tap-deferred-opts {}
	after {}
	frequencies {}
	tap-options {-server -size -polyphase -result}
	tk-options {-sample-rate -pal -max -min -smooth -multi -zoom -pan -mode -freq -lo-freq -cw-freq -carrier-freq -low -high}
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
	set data(display) [sdrui::tk-spectrum .spectrum-$options(-name).s -width 1024 {*}[$self TkOptions]]
	pack $data(display) -side top -fill both -expand true
	sdrtcl::spectrum-tap ::sdrkitx::$options(-name) {*}[$self TapOptions]
	set data(after) [after $options(-period) [mymethod Update]]
    }
    method build-ui {} {
	if {$options(-window) eq {none}} return
	set w $options(-window)
	if {$w eq {}} { set pw . } else { set pw $w }

	foreach {opt type opts} $options(-sub-controls) {
	    switch $type {
		spinbox {
		    package require sdrkit::label-spinbox
		    sdrkit::label-spinbox $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		scale {
		    package require sdrkit::label-scale
		    #lappend opts -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max]
		    sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		iscale {
		    package require sdrkit::label-iscale
		    #lappend opts -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max]
		    sdrkit::label-iscale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		separator {
		    ttk::separator $w.$opt
		}
		radio {
		    package require sdrkit::label-radio
		    #lappend opts -defaultvalue $options(-$opt) -values [sdrtype::agc-$opt cget -values]
		    sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		}
		default { error "unimplemented control type \"$type\"" }
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method Set {opt val} {
	if { ! [info exists data(Set-dispatch$opt)]} {
	    if {$opt in $data(tap-options)} {
		set data(Set-dispatch$opt) [mymethod TapConfigure]
	    } elseif {$opt in $data(tk-options)} {
		set data(Set-dispatch$opt) [mymethod TkConfigure]
	    } else {
		set data(Set-dispatch$opt) [mymethod Configure]
	    }
	}
	{*}$data(Set-dispatch$opt) $opt $val
    }
    method is-busy {} { return [::sdrkitx::$options(-name) is-busy] }
    method is-active {} { return [::sdrkitx::$options(-name) is-active]  }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }
    method FilterOptions {keepers} { foreach opt $keepers { lappend opts $opt $options($opt) }; return $opts }
    method TapOptions {} { return [$self FilterOptions $data(tap-options)] }
    method TkOptions {} { return [$self FilterOptions $data(tk-options)] }

    method OptionConstrain {opt val} {
	switch -- $opt {
	    -size - -polyphase - -multi - -pal - -min - -max - -pan - -period {
		return [expr {int(round($val))}]
	    }
	    -smooth - -zoom { return $val }
	    default { error "unanticipated option \"$opt\"" }
	}
    }
    method Configure {opt val} {
	set options($opt) [$self OptionConstrain $opt $val]
    }
    method TapConfigure {opt val} {
	$self Configure $opt $val
	lappend data(tap-deferred-opts) $opt $options($opt)
    }
    method TkConfigure {opt val} {
	$self Configure $opt $val
	$data(display) configure $opt $options($opt)
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
	foreach x $data(frequencies) y [concat [lrange $dB [expr {$n/2}] end] [lrange $dB 0 [expr {($n/2)-1}]]] {
	    lappend xy $x $y
	}
	#puts "$xy"
	$data(display) update $xy
	
	# start the next
	set data(after) [after $options(-period) [mymethod Update]]
    }
}
