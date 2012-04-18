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

package provide sdrblk::radio-control 1.0.0

package require snit

snit::type sdrblk::radio-control {
    variable order {}
    variable parts -array {}

    option -partof -readonly yes

    constructor {args} { $self configure {*}$args }

    destructor {}

    method add {name block} {
	if {[info exists parts($name)]} { error "control part $name already exists" }
	set parts($name) $block
	lappend order $name
    }

    method remove {name} {
	if { ! [info exists parts($name)]} { error "control part $name does not exist" }
	unset parts($name)
	set i [lsearch -exact $order $name]
	if {$i >= 0} {
	    set order [lreplace $order $i $i]
	}
    }

    method exists {name} { return [info exists parts($name)] }
    method list {} { return $order }
    method show {name} { return $parts($name) }
    method controls {name} { return [$parts($name) controls] }
    method control {name args} { $parts($name) control {*}$args }
    method controlget {name opt} { return [$parts($name) controlget $opt] }
    method ccget {name opt} { return [$parts($name) cget $opt] }
    method cconfigure {name args} { return [$parts($name) configure {*}$args] }
    method enable {name} { $parts($name) configure -enable yes }
    method disable {name} { $parts($name) configure -enable no }
    method is-enabled {name} { return [$parts($name) cget -enable] }
    method activate {name} {
	$parts($name) configure -activate yes
	$parts($name) connect
    }
    method deactivate {name} {
	$parts($name) disconnect
	$parts($name) configure -activate no
    }
    method is-activated {name} { return [$parts($name) cget -activate] }
    method filter-parts {pred} { set list {}; foreach name $order { if {[$pred $name]} { lappend list $name } }; return $list }
    method enabled {} { return [filter-parts [mymethod is-enabled]] }
    method activated {} { return [filter-parts [mymethod is-activated]] }

}

