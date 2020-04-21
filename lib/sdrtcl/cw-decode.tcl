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
package provide sdrtcl::cw-decode 0.0.1

package require snit
package require morse::morse
package require morse::itu
package require morse::dicts


snit::type sdrtcl::cw-decode {
    option -detime -default {}
    option -dict -default fldigi

    variable data -array {
	active 0
	code {}
	text {}
    }
    method is-busy {} { return 0 }
    method activate {} { set data(active) 1 }
    method deactivate {} { set data(active) 0 }
    method is-active {} { return $data(active) }

    method info-option {opt} {
	switch -- $opt {
	    -detime { return {detiming component which supplies didahs and spaces} }
	    -dict { return {dictionary to use for translating didah into characters} }
	    default { error "no match for $opt in [$self info type]" }
	}
    }
    
    constructor {args} {
	$self configurelist $args
	after 250 [mymethod timeout]
    }

    method timeout {} {
	# get new text
	# append to accumulated code
	if { ! [$options(-detime) is-busy]} {
	    append data(code) [$options(-detime) get]
	    while {[regexp {^([-.]*) (.*)$} $data(code) all symbol data(code)]} {
		if {$symbol ne {}} {
		    # symbol terminated by a space
		    # insert translation
		    append data(text) [morse-to-text [$options(-dict)] $symbol]
		} else {
		    # an extra space indicates a word space
		    append data(text) { }
		}
	    }
	}
	set handler [after 250 [mymethod timeout]]
    }

    method get {} {
	set text $data(text)
	set data(text) {}
	return $text
    }
}

