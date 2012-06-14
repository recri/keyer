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
# common component services for alternate path wrappers
#
package provide sdrkit::common-alternate 1.0.0

package require snit

package require sdrkit::common-component

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::common-alternate {
    option -parent {}

    variable data -array {
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor {
	$common destroy
    }
    method Rewrite-connections-to {name selected port candidates} {
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
    method Rewrite-connections-from {name selected port candidates} {
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
