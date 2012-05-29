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
# a composite component that builds a transceiver
#
package provide sdrkit::rxtx 1.0.0

package require snit
package require sdrkit::control-dial
package require sdrtk::cnotebook
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::rxtx {
    option -name rxtx
    option -type dsp
    option -title {RXTX}
    option -in-ports {}
    option -out-ports {}

    option -mox -default 0 -configuremethod Configure
    option -freq -default 7050000 -configuremethod Configure
    option -tune-rate -default 50 -configuremethod Configure
    option -lo-freq -default 10000 -configuremethod Configure
    option -lo-tune-rate -default 50 -configuremethod Configure
    option -cw-freq -default 400 -configuremethod Configure
    option -mode -default CWU -configuremethod Configure
    option -agc-mode -default medium -configuremethod Configure
    option -iq-swap -default 0 -configuremethod Configure
    option -iq-delay -default 0 -configuremethod Configure
    option -iq-correct -default 0 -configuremethod Configure
    option -bpf-width -default 200 -configuremethod Configure
    option -bpf-offset -default 150 -configuremethod Configure
    option -rx-rf-gain -default 0 -configuremethod Configure
    option -rx-af-gain -default 0 -configuremethod Configure
    option -hw-freq -default [expr {7050000-10000-400}] -readonly true

    option -in-options {
	-mox -freq -tune-rate -lo-freq -lo-tune-rate -cw-freq
	-mode -agc-mode -iq-correct -iq-swap -iq-delay
	-bpf-width -bpf-offset -rx-rf-gain -rx-af-gain
    }
    option -out-options {
	-mox -freq -tune-rate -lo-freq -lo-tune-rate -cw-freq
	-mode -agc-mode -iq-correct -iq-swap -iq-delay
	-bpf-width -bpf-offset -rx-rf-gain -rx-af-gain -hw-freq
    }
    
    option -sub-components {
	ctl {Control} rxtx-control {}
	rx {RX} rx {}
	tx {TX} tx {}
	keyer {Key} keyer {}
    }

    option -sub-controls {
	mox radio {-format {MOX} -values {0 1} -labels {Off On}}
	freq scale {-format {Freq %.0f Hz} -from 1000000 -to 30000000}
	lo-freq scale {-format {LO %.0f Hz}  -from -24000 -to 24000}
	cw-freq scale {-format {CW Tone %.0f Hz} -from 100 -to 1000}
	mode radio {-format {Mode} -values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}}
	bpf-width scale {-format {Width %.0f Hz} -from 10 -to 50000}
	bpf-offset scale {-format {Offset %.0f Hz} -from 10 -to 1000}
    }

    option -port-connections {
    }
    option -opt-connections {
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -rx-source {}
    option -rx-sink {}
    option -rx-enable {}
    option -rx-activate {}
    option -tx-source {}
    option -tx-sink {}
    option -keyer-source {}
    option -keyer-sink {}
    option -physical true
    option -hardware {}

    variable data -array {
	parts {}
	active 0
    }

    constructor {args} { $self configure {*}$args }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	}
	if {$options(-physical) ne {}} {
	    $self sub-component none ports sdrkit::physical-ports -physical $options(-physical)
	    $options(-component) part-configure $options(-name)-ports -enable true -activate true
	}
	if {$options(-hardware) ne {}} {
	    $self sub-component none hardware sdrkit::hardware -hardware $options(-hardware)
	}
	if {$w ne {none}} {
	    sdrkit::control-dial $w.dial -command [mymethod Set]
	    sdrtk::cnotebook $w.note
	}
	foreach {name title command args} $options(-sub-components) {
	    switch $name {
		ctl {}
		rx { lappend args -rx-source $options(-rx-source) -rx-sink $options(-rx-sink) }
		tx { lappend args -tx-source $options(-tx-source) -tx-sink $options(-tx-sink) }
		keyer { lappend args -keyer-source $options(-keyer-source) -keyer-sink $options(-keyer-sink) }
		default { error "rxtx::build-ui unknown name \"$name\"" }
	    }
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		$self sub-component [ttk::frame $w.note.$name] $name sdrkit::$command {*}$args
		$w.note add $w.note.$name -text $title
	    }
	}
	if {$w ne {none}} {
	    grid $w.dial -sticky nsew -row 0
	    grid $w.note -sticky nsew -row 1
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }

    method resolve {} {
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	foreach {name1 opt1 name2 opt2} $options(-opt-connections) {
	    $options(-component) connect-opts $name1 $opt1 $name2 $opt2
	}
	if {$options(-rx-enable) ne {} && $options(-rx-enable)} {
	    $options(-component) part-enable $options(-name)-rx
	}
	if {$options(-rx-activate) ne {} && $options(-rx-activate)} {
	    $options(-component) part-activate $options(-name)-rx
	}
    }

    method OptionConstrain {opt val} { return $val }
    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} { $options(-window).dial configure $opt $val }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	if {$opt eq {-lo-freq}} {
	    set df [expr {$val-$options(-lo-freq)}]
	    $self Set -freq [expr {$options(-freq)+$df}]
	}
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
