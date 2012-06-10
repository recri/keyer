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
# a composite component which switches between modulation implementations
#
package provide sdrkit::mod 1.0.0

package require snit
package require sdrtk::clabelframe
package require sdrtk::radiomenubutton

namespace eval sdrkit {}

snit::type sdrkit::mod {
    option -name mod
    option -type dsp
    option -title {Mod}
    option -in-ports {alt_in_i alt_in_q}
    option -out-ports {alt_out_i alt_out_q}
    option -options {-mode}

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -mode -default none -configuremethod Configure

    option -sub-components {
	am {AM} mod-am {}
	fm {FM} mod-fm {}
	ssb {SSB} mod-ssb {}
    }

    option -port-connections {
	{} in-ports am in-ports		am out-ports {} in-ports
	{} in-ports fm in-ports		fm out-ports {} out-ports
	{} in-ports ssb in-ports	ssb out-ports {} out-ports
    }
    option -opt-connections {
    }

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    constructor {args} {
	# puts "$self constructor"
	$self configure {*}$args
    }
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
	sdrkit::label-radio $w.mode -format {Mode} -values $values -labels $labels -variable [myvar options(-mode)] -command [mymethod Set -mode]
	grid $w.mode
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method is-active {} { return 1 }
    method activate {} {}
    method deactivate {} {}
    method Constrain {opt val} { return $val }
    method Configure {opt name} {
	set options($opt) $name
	# find deselected component
	set exname {none}
	foreach part $data(parts) {
	    if {$data(enable-$part)} {
		if {$exname ne {none}} { error "multiple selected keyers $part and $exname" }
		set exname $part
	    }
	}
	# enable selected component if any
	if {$name ne {none}} {
	    set data(enable-$name) 1
	    $options(-component) part-enable $options(-name)-$name
	}
	# disable deselected keyer
	if {$exname ne {none}} {
	    set data(enable-$exname) 0
	    $options(-component) part-disable $options(-name)-$exname
	}
	# deal with ui details
	set w $options(-window)
	# determine if ui details exist
	if {$w ne {none}} {
	    # remove deselected keyer ui
	    if {$exname ne {none}} {
		grid forget $data(window-$exname)
	    }
	    # install selected keyer ui
	    if {$name ne {none}} {
		grid $data(window-$name) -row 1 -column 0 -columnspan 2 -sticky ew
	    }
	}
    }
    method Set {opt val} {
	$options(-component) report $opt [$self Constrain $opt $val]
    }
    method rewrite-connections-to {port candidates} {
	# puts "mod::rewrite-connections-to $port {$candidates}"
	if {$options(-mode) eq {none}} {
	    return [Rewrite-connections-to {} $port $candidates]
	} else {
	    return [Rewrite-connections-to $options(-name)-$options(-mode) $port $candidates]
	}
    }
    method rewrite-connections-from {port candidates} {
	if {$options(-mode) eq {none}} {
	    return [Rewrite-connections-from {} $port $candidates]
	} else {
	    return [Rewrite-connections-from $options(-name)-$options(-mode) $port $candidates]
	}
    }
    proc Rewrite-connections-to {selected port candidates} {
	# puts "mod::Rewrite-connections-to $port {$candidates}"
	if {$port ni {alt_out_i alt_out_q alt_midi_out}} { return $candidates }
	if {$selected eq {}} {
	    switch $port {
		alt_out_i { return [list [list $port alt_in_i]] }
		alt_out_q { return [list [list $port alt_in_q]] }
		alt_midi_out { return [list [list $port alt_midi_in]] }
		default { error "rewrite-connections-to: unexpected port \"$port\"" }
	    }
	} else {
	    foreach c $candidates {
		if {[string match [list $selected *] $c]} {
		    return [list $c]
		}
	    }
	    error "rewrite-connections-to: failed to match $data(selected-client) in $candidates"
	}
    }
    proc Rewrite-connections-from {selected port candidates} {
	#puts "$options(-name) rewrite-connections-from $port {$candidates}"
	if {$port ni {alt_in_i alt_in_q alt_midi_in}} { return $candidates }
	if {$selected eq {}} {
	    switch $port {
		alt_in_i { return [list [list $port alt_out_i]] }
		alt_in_q { return [list [list $port alt_out_q]] }
		alt_midi_in { return [list [list $port alt_midi_out]] }
		default { error "rewrite-connections-from: unexpected port \"$port\"" }
	    }
	} else {
	    foreach c $candidates {
		if {[string match [list $selected *] $c]} {
		    return [list $c]
		}
	    }
	    error "rewrite-connections-from: failed to match $data(selected-client) in $candidates"
	}
    }
}

