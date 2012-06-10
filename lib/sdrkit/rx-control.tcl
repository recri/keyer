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
# the rx control component
#
package provide sdrkit::rx-control 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::rx-control {    
    option -name rx-control
    option -type ctl
    option -server default
    option -component {}

    option -window none
    option -title {RX Control}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {}
    option -in-options {-mode -width -offset -freq -lo2-freq -cw-freq}
    option -out-options {-mode -width -offset -freq -lo1-freq -lo2-freq -cw-freq -carrier}

    option -sample-rate 0

    option -mode -default CWU -configuremethod Retune -type sdrtype::mode
    option -width -default 400 -configuremethod Retune
    option -offset -default 150 -configuremethod Retune
    option -freq -default 7050000 -configuremethod Retune
    option -lo1 -default 7039400 -configuremethod Opt-handler
    option -lo2 -default 10000 -configuremethod Retune
    option -cw -default 600 -configuremethod Retune
    option -carrier -default 7040000 -configuremethod Opt-handler

    option -sub-controls {
	mode radio {-format {Mode} -values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}}
	width scale {-format {Width %.0f Hz} -from 10 -to 50000}
	offset scale {-format {Offset %.0f Hz} -from 10 -to 1000}
	freq scale {-format {Freq %.0f Hz} -from 1000000 -to 30000000}
	lo2 scale {-format {LO2 %.0f Hz}  -from -24000 -to 24000}
	cw scale {-format {CW Tone %.0f Hz} -from 100 -to 1000}
    }

    variable data -array {}

    constructor {args} {
	$self configure {*}$args
	$self configure -sample-rate [sdrtcl::jack -server $options(-server) sample-rate]
    }
    destructor {}
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	    foreach {opt type opts} $options(-sub-controls) {
		if {$opt eq {lo2}} { lappend opts -from [expr {-$options(-sample-rate)/4.0}] -to [expr {$options(-sample-rate)/4.0}] }
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
		    separator {
			ttk::separator $w.$opt
		    }
		    radio {
			package require sdrkit::label-radio
			#lappend opts -defaultvalue $options(-$opt) -values [sdrtype::agc-$opt cget -values]
			sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		    }
		}
		grid $w.$opt -sticky ew
	    }
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }
    method is-needed {} { return 1 }
    method is-active {} { return 1 }
    method activate {} { }
    method deactivate {} { }
    method Constrain {opt val} { return $val }
    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {}
    method ControlConfigure {opt val} { $options(-component) report $opt $val }
    method Configure {opt val} {
	set val [$self Constrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
    }
    method Set {opt val} {
	set val [$self Constrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
