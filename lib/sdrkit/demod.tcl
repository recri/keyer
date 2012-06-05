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
# a composite component which switches between demodulation implementations
#
package provide sdrkit::demod 1.0.0

package require snit
package require sdrtk::clabelframe
package require sdrtk::radiomenubutton

namespace eval sdrkit {}

snit::type sdrkit::demod {
    option -name demod
    option -type dsp
    option -title {Demod}
    option -in-ports {alt_in_i alt_in_q}
    option -out-ports {alt_out_i alt_out_q}
    option -in-options {-demod}
    option -out-options {-demod}
    option -sub-components {
	am {AM} demod-am {}
	fm {FM} demod-fm {}
	sam {SAM} demod-sam {}
    }
    option -port-connections {
	{} in-ports am in-ports		am out-ports {} out-ports
	{} in-ports fm in-ports		fm out-ports {} out-ports
	{} in-ports sam in-ports	sam out-ports {} out-ports
    }
    option -opt-connections {
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -demod -default none -configuremethod Configure

    variable data -array { parts {} }

    constructor {args} { $self configure {*}$args }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method resolve {} {
	# need to match midi vs audio
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	foreach {name1 opts1 name2 opts2} $options(-opt-connections) {
	}
    }
    method build-parts {} {
	if {$options(-window) ne {none}} return
	foreach {name title command args} $options(-sub-components) {
	    $self sub-component none $name sdrkit::$command {*}$args
	}
    }
    method build-ui {} {
	if {$options(-window) eq {none}} return
	set w $options(-window)
	if {$w eq {}} { set pw . } else { set pw $w }
	
	set values {none}
	set labels {none}
	foreach {name title command args} $options(-sub-components) {
	    lappend values $name
	    lappend labels $title
	    set data(window-$name) [sdrtk::clabelframe $w.$name -label $title]
	    $self sub-component [ttk::frame $w.$name.container] $name sdrkit::$command {*}$args
	    grid $w.$name.container
	    grid columnconfigure $w.$name 0 -weight 1 -minsize [tcl::mathop::+ {*}$options(-minsizes)]
	}
	package require sdrkit::label-radio
	sdrkit::label-radio $w.mode -format {Mode} -values $values -labels $labels -variable [myvar options(-demod)] -command [mymethod Set -demod]
	grid $w.mode
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method {Configure -demod} {val} {
	switch $val {
	    CWU - CWL - USB - LSB - DIGU - DIGL - DSB { $self Set -demod none }
	    FMN { $self Set -demod FM }
	    AM { $self Set -demod AM }
	    SAM { $self Set -demod SAM }
	    default { error "unanticipated demodulation \"$val\"" }
	}
    }
    method Set {opt name} {
	# find deselected component
	set exname {none}
	foreach part $data(parts) {
	    if {[$options(-component) part-is-enabled $options(-name)-$part]} {
		if {$exname ne {none}} { error "multiple selected keyers $part and $exname" }
		set exname $part
	    }
	}
	# enable selected component if any
	if {$name ne {none}} { $options(-component) part-enable $options(-name)-$name }
	# disable deselected keyer
	if {$exname ne {none}} { $options(-component) part-disable $options(-name)-$exname }
	# deal with ui details
	set w $options(-window)
	# determine if ui details exist
	if {$w ne {none}} {
	    # remove deselected keyer ui
	    if {$exname ne {none}} { grid forget $data(window-$exname) }
	    # install selected keyer ui
	    if {$name ne {none}} { grid $data(window-$name) -row 1 -column 0 -columnspan 2 -sticky ew }
	}
    }
    method rewrite-connections-to {port candidates} {
	return [Rewrite-connections-to $options(-name) $options(-demod) $port $candidates]
    }
    method rewrite-connections-from {port candidates} {
	return [Rewrite-connections-from $options(-name) $options(-demod) $port $candidates]
    }
    proc Rewrite-connections-to {name selected port candidates} {
	#puts "Rewrite-connections-to {$selected} $name $port {$candidates}"
	if {$port ni {alt_out_i alt_out_q alt_midi_out}} { return $candidates }
	foreach c $candidates {
	    if {[string match [list $name-$selected *] $c]} { return [list $c] }
	}
	if {$selected in {none {}}} {
	    switch $port {
		alt_out_i { return [list [list $name alt_in_i]] }
		alt_out_q { return [list [list $name alt_in_q]] }
		alt_midi_out { return [list [list $name alt_midi_in]] }
		default { error "rewrite-connections-to: unexpected port \"$port\"" }
	    }
	}
	error "rewrite-connections-to: failed to match $selected in $candidates"
    }
    proc Rewrite-connections-from {name selected port candidates} {
	#puts "Rewrite-connections-from {$selected} $name $port {$candidates}"
	if {$port ni {alt_in_i alt_in_q alt_midi_in}} { return $candidates }
	foreach c $candidates {
	    if {[string match [list $name-$selected *] $c]} { return [list $c] }
	}
	if {$selected in {none {}}} {
	    switch $port {
		alt_in_i { return [list [list $name alt_out_i]] }
		alt_in_q { return [list [list $name alt_out_q]] }
		alt_midi_in { return [list [list $name alt_midi_out]] }
		default { error "rewrite-connections-from: unexpected port \"$port\"" }
	    }
	}
	error "rewrite-connections-from: failed to match $selected in $candidates"
    }
}

