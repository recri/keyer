# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA
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
# switch between iambic keyers
# this needs to load the union of all options 
# and protect the innocent from unknown options
#
package provide sdrtcl::keyer-iambic 0.0.1

package require snit
package require sdrtcl::jack
package require sdrtcl::keyer-iambic-ad5dz

snit::type sdrtcl::keyer-iambic {
    option -keyer -default ad5dz -configuremethod Configure

    component keyer

    # removed lists of mode values:  {abs} for A, B, or Straight key
    variable data -array {
	ad5dz {-verbose -server -client -chan -note -wpm -swap -two -mode -dit -dah -ies -ils -iws -alsp -awsp -weight -ratio -comp -word}
	dttsp {-verbose -server -client -chan -note -wpm -swap -two -mode                          -alsp -awsp -weight                    -mdit -mdah -mide}
	k1el  {-verbose -server -client -chan -note -wpm -swap -two -mode -dit -dah -ies                                            -word}
	nd7pa {-verbose -server -client -chan -note -wpm -swap -two       -dit -dah -ies}
	vk6ph {-verbose -server -client -chan -note -wpm -swap -two -mode                          -alsp               -ratio}
    }

    option -verbose -default 0 -configuremethod Configure -cgetmethod Cget
    option -server -default {} -configuremethod Configure -cgetmethod Cget
    option -client -default {} -configuremethod Configure -cgetmethod Cget
    option -chan -default 1 -configuremethod Configure -cgetmethod Cget
    option -note -default 0 -configuremethod Configure -cgetmethod Cget
    option -wpm -default 25.0 -configuremethod Configure -cgetmethod Cget
    option -swap -default 0 -configuremethod Configure -cgetmethod Cget

    option -mode -default A -configuremethod Configure -cgetmethod Cget
    option -dit -default 1.0 -configuremethod Configure -cgetmethod Cget
    option -dah -default 3.0 -configuremethod Configure -cgetmethod Cget
    option -ies -default 1.0 -configuremethod Configure -cgetmethod Cget
    option -ils -default 3.0 -configuremethod Configure -cgetmethod Cget
    option -iws -default 7.0 -configuremethod Configure -cgetmethod Cget

    option -alsp -default 0 -configuremethod Configure -cgetmethod Cget
    option -awsp -default 0 -configuremethod Configure -cgetmethod Cget
    option -weight -default 50 -configuremethod Configure -cgetmethod Cget
    option -ratio -default 50 -configuremethod Configure -cgetmethod Cget
    option -comp -default 0 -configuremethod Configure -cgetmethod Cget
    option -word -default 50 -configuremethod Configure -cgetmethod Cget
    option -mdit -default 0 -configuremethod Configure -cgetmethod Cget
    option -mdah -default 0 -configuremethod Configure -cgetmethod Cget
    option -mide -default 0 -configuremethod Configure -cgetmethod Cget

    option -two -default 0 -configuremethod Configure -cgetmethod Cget
    
    # configure cget cset info is-busy activate deactivate is-active

    method is-busy {} { return [$keyer is-busy] }
    method activate {} { $keyer activate }
    method deactivate {} { $keyer deactivate }
    method is-active {} { return [$keyer is-active] }

    variable optinfo
    method info-option {opt} {
	if { ! [catch {$keyer info option $opt} result] } { return $result }
	switch $opt {
	    -keyer { return {select iambic keyer} }
	    -verbose { return {amount of diagnostic output} }
	    -server { return {jack server name} }
	    -client { return  {jack client name} }
	    -chan { return  {midi channel} }
	    -note { return  {base midi note} }
	    -wpm { return  {words per minute} }
	    -word { return  {dits in a word} }
	    -dit { return  {dit length in dits} }
	    -dah { return  {dah length in dits} }
	    -ies { return  {inter-element space in dits} }
	    -ils { return  {inter-letter space in dits} }
	    -iws { return  {inter-word space in dits} }
	    -swap { return  {swap the dit and dah paddles} }
	    -alsp { return  {auto letter spacing} }
	    -awsp { return  {auto word spacing} }
	    -mode { return  {iambic keyer mode: A, B, or perhaps S} }
	    -weight { return  {keyer mark/space weight} }
	    -ratio { return  {keyer dit/dah ratio} }
	    -comp { return  {keyer ms compensation} }
	    -mdit { return  {keep a dit memory} }
	    -mdah { return  {keep a dah memory} }
	    -mide { return  {remember key state at mid-element} }
	    -two { return {enable independent dit dah keyout} }
	    default { error "no match for $opt in keyer-iambic info-option" }
	}
    }
    
    constructor {args} {
	set options(-client) [namespace tail $self]
	install keyer using sdrtcl::keyer-iambic-$options(-keyer) $self.keyer -client $options(-client) {*}$args
    }
    
    method Configure {opt val} {
	# puts "keyer-iambic::Configure $opt $val"
	set options($opt) $val
	if {$opt eq {-keyer}} {
	    set connections {}
	    dict for {port props} [sdrtcl::jack list-ports] {
		if {$port eq "$options(-client):midi_in"} {
		    lappend connections [dict get $props connections] $options(-client):midi_in
		} elseif {$port eq "$options(-client):midi_out"} {
		    lappend connections $options(-client):midi_out [dict get $props connections]
		}
	    }
	    $keyer deactivate
	    rename $self.keyer {}
	    set opts {}
	    foreach opt $data($val) {
		if {$opt eq {-server} && $options($opt) eq {}} continue
		lappend opts $opt $options($opt)
	    }
	    package require sdrtcl::keyer-iambic-$val
	    install keyer using sdrtcl::keyer-iambic-$val $self.keyer {*}$opts
	    $keyer activate
	    # restore connections
	    foreach {port1 port2} $connections { sdrtcl::jack connect $port1 $port2 }
	} else {
	    if { ! [catch {$keyer configure $opt $val} result]} { return $result }
	}
	return {}
    }
 
    method Cget {opt} {
	if {$opt eq {-keyer}} { return $options($opt) }
	if {[lsearch $data($options(-keyer)) $opt] >= 0} {
	    return [$keyer cget $opt]
	} else {
	    return $options($opt)
	}
    }

}

