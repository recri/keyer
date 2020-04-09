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
package require sdrtcl::keyer-iambic-ad5dz

snit::type sdrtcl::keyer-iambic {
    option -keyer -default ad5dz -configuremethod Configure

    component keyer

    variable data -array {
	ad5dz {-verbose -server -client -chan -note -wpm -swap -mode -ies -ils -iws -dit -dah -alsp -awsp -weight -ratio -comp -word}
	dttsp {-verbose -server -client -chan -note -wpm -swap -mode                          -alsp -awsp -weight                    -mdit -mdah -mide}
	k1el  {-verbose -server -client -chan -note -wpm -swap -mode -ies           -dit -dah             -weight -ratio -comp -word}
	nd7pa {-verbose -server -client -chan -note -wpm -swap       -ies           -dit -dah             -weight -ratio -comp}
	vk6ph {-verbose -server -client -chan -note -wpm -swap -mode                          -alsp               -ratio}
    }

    delegate option -verbose to keyer
    delegate option -server to keyer
    delegate option -client to keyer
    delegate option -chan to keyer
    delegate option -note to keyer
    delegate option -wpm to keyer
    delegate option -swap to keyer

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
	    default { error "no match for $opt in keyer-iambic info-option" }
	}
    }
    
    constructor {args} {
	install keyer using sdrtcl::keyer-iambic-$options(-keyer) $self.keyer -client $self
	$self configurelist $args
    }
    
    method Configure {opt val} {
	if {$opt eq {-keyer}} {
	    $keyer deactivate
	    rename $self.keyer {}
	    set options($opt) $val
	    package require sdrtcl::keyer-iambic-$val
	    install keyer using sdrtcl::keyer-iambic-$val $self.keyer -client $self
	    $keyer activate
	    make-connections
	    foreach opt [$keyer info options] {
		if {[info exists options($opt)]} {
		    $keyer configure $opt $options($opt)
		}
	    }
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

