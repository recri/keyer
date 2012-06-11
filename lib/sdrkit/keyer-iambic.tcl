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
# a composite component which switches betwee iambic keyer implementations
#
package provide sdrkit::keyer-iambic 1.0.0

package require snit
package require sdrtk::clabelframe
package require sdrtk::radiomenubutton

namespace eval sdrkit {}

snit::type sdrkit::keyer-iambic {
    option -name keyer
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {alt_midi_in}
    option -out-ports {alt_midi_out}
    option -options {-iambic}

    option -sub-components {
	ad5 {ad5dz} keyer-iambic-ad5dz {}
	dtt {dttsp} keyer-iambic-dttsp {}
	nd7 {nd7pa} keyer-iambic-nd7pa {}
    }
    option -port-connections {
	{} in-ports ad5 in-ports	ad5 out-ports {} out-ports
	{} in-ports dtt in-ports	dtt out-ports {} out-ports
	{} in-ports nd7 in-ports	nd7 out-ports {} out-ports
    }
    option -opt-connections {
    }

    option -iambic -default none -configuremethod Configure

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
    method build-parts {w} {
	if {$w ne {none}} return
	foreach {name title command args} $options(-sub-components) {
	    $self sub-component none $name sdrkit::$command {*}$args
	}
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	set values {none}
	set labels {none}
	foreach {name title command args} $options(-sub-components) {
	    lappend values $name
	    lappend labels $title
	    set data(window-$name) [sdrtk::clabelframe $w.$name -label $title]
	    $self sub-component [ttk::frame $w.$name.container] $name sdrkit::$command {*}$args
	    grid $w.$name.container
	    grid columnconfigure $w.$name 0 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	}
	package require sdrkit::label-radio
	sdrkit::label-radio $w.mode -format {Keyer} -values $values -labels $labels -variable [myvar options(-iambic)] -command [mymethod Set -iambic]
	grid $w.mode
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
    ## these are specific to this component
    method is-needed {} { return 1 }
    method Constrain {opt val} { return $val }
    ## 
    method is-active {} { return 1 }
    method is-busy {} { return 0 }
    method activate {} {}
    method deactivate {} {}
    method {Configure -iambic} {name} {
	set options($opt) $name
	# find deselected keyer
	set exname {none}
	foreach part $data(parts) {
	    if {[$options(-component) part-is-enabled $options(-name)-$part]} {
		if {$exname ne {none}} { error "multiple selected keyers $part and $exname" }
		set exname $part
	    }
	}
	# enable selected keyer if any
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
    method Set {opt val} {
	$options(-component) report $opt [$self Constrain $opt $val]
    }
    method rewrite-connections-to {port candidates} {
	# puts "demod::rewrite-connections-to $port {$candidates}"
	if {$options(-iambic) eq {none}} {
	    return [Rewrite-connections-to {} $port $candidates]
	} else {
	    return [Rewrite-connections-to $options(-name)-$options(-iambic) $port $candidates]
	}
    }
    method rewrite-connections-from {port candidates} {
	if {$options(-iambic) eq {none}} {
	    return [Rewrite-connections-from {} $port $candidates]
	} else {
	    return [Rewrite-connections-from $options(-name)-$options(-iambic) $port $candidates]
	}
    }
    proc Rewrite-connections-to {selected port candidates} {
	# puts "demod::Rewrite-connections-to $port {$candidates}"
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
