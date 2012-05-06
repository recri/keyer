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

package provide sdrdsp::dsp-alternates 1.0.0

package require snit
package require sdrdsp::dsp-ports

snit::type sdrdsp::dsp-alternates {
    component ports

    option -ports -default {alt_in_i alt_in_q alt_out_i alt_out_q}
    option -opts -default {-select}
    option -methods -default {rewrite-connections-to rewrite-connections-from}

    option -container -default {} -readonly true
    option -control -default {} -readonly true
    option -require -default {} -readonly true
    
    option -name {}
    option -alternates -default {} -readonly true
    option -map -default {} -readonly true
    option -signal -default {}
    option -opt-connect-from -default {} -readonly true

    option -select -default {} -configuremethod Select

    variable data -array {
	selected-client {}
	old-selected-client {}
	new-selected-client {}
    }

    constructor {args} {
	# puts "dsp-alternates constructor $self {$args}"
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	set options(-name) [$options(-container) cget -name]
	set data(map) [dict create {*}$options(-map)]
	install ports using sdrdsp::dsp-ports %AUTO% -control $options(-control)
    }

    destructor { $self alternates destructor }
    method finish {} { $self alternates constructor }

    method {alternates constructor} {} {
	# build the components of the sequence
	foreach package $options(-require) {
	    package require $package
	}
	foreach element $options(-alternates) {
	    set element [$element %AUTO% -container $options(-container)]
	    lappend data(alternates) $element
	    # want an enable callback to catch undisciplined manipulations?
	    # "connect" the components of the sequence
	    $ports connect [$ports inputs $options(-container)] [$ports inputs $element]
	    $ports connect [$ports outputs $element] [$ports outputs $options(-container)]
	}
	set data(map) [dict create]
	foreach {value index} $options(-map) {
	    if {$index < 0} {
		dict set data(map) $value {}
	    } elseif {$index < [llength $data(alternates)]} {
		dict set data(map) $value [[lindex $data(alternates) $index] cget -name]
	    } else {
		error "map contains \"$index\" which is out of range"
	    }
	}
    }
    
    method {alternates destructor} {} {
	catch {
	    foreach element $data(alternates) {
		catch {$element destroy}
	    }
	}
    }

    method rewrite-connections-to {port candidates} {
	#puts "$options(-name) rewrite-connections-to $port {$candidates}"
	if {$port ni {alt_out_i alt_out_q alt_midi_out}} { return $candidates }
	if {$data(selected-client) eq {}} {
	    switch $port {
		alt_out_q { return [list [list $port alt_in_i]] }
		alt_out_i { return [list [list $port alt_in_q]] }
		alt_midi_out { return [list [list $port alt_midi_in]] }
		default { error "rewrite-connections-to: unexpected port \"$port\"" }
	    }
	} else {
	    foreach c $candidates {
		if {[string match [list $data(selected-client) *] $c]} {
		    return [list $c]
		}
	    }
	    error "rewrite-connections-to: failed to match $data(selected-client) in $candidates"
	}
    }

    method rewrite-connections-from {port candidates} {
	#puts "$options(-name) rewrite-connections-from $port {$candidates}"
	if {$port ni {alt_in_i alt_in_q alt_midi_in}} { return $candidates }
	if {$data(selected-client) eq {}} {
	    switch $port {
		alt_in_i { return [list [list $port alt_out_q]] }
		alt_in_q { return [list [list $port alt_out_i]] }
		alt_midi_in { return [list [list $port alt_midi_out]] }
		default { error "rewrite-connections-from: unexpected port \"$port\"" }
	    }
	} else {
	    foreach c $candidates {
		if {[string match [list $data(selected-client) *] $c]} {
		    return [list $c]
		}
	    }
	    error "rewrite-connections-from: failed to match $data(selected-client) in $candidates"
	}
    }

    method {Select -select} {val} {
	set options(-select) $val
	if {[dict exists $data(map) $val]} {
	    set data(new-selected-client) [dict get $data(map) $val]
	    #puts "dsp-alternates $self select $val -> $data(new-selected-client)"
	    if {$data(selected-client) eq $data(new-selected-client)} return
	    if {$data(selected-client) ne {}} {
		set data(old-selected-client) $data(selected-client)
		set data(selected-client) {}
		$options(-control) part-disable $data(old-selected-client)
	    }
	    set data(selected-client) $data(new-selected-client)
	    if {$data(selected-client) ne {}} {
		$options(-control) part-enable $data(new-selected-client)
	    }
	} else {
	    error "dsp-alternates $self select $val -> nomatch"
	}
    }

    method deactivate {} {}
    method activate {} {}
    
}

