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

::snit::type sdrblk::radio-control {
    variable parts -array {}
    variable enabled -array {}

    option -partof -readonly yes

    constructor {args} { $self configure {*}$args }

    destructor {}

    method add {name args} {
	if {[info exists parts($name)]} { error "control part $name already exists" }
	set parts($name) $args
	set enabled($name) 0
    }

    method remove {name} {
	if { ! [info exists parts($name)]} { error "control part $name does not exist" }
	unset parts($name)
	unset enabled($name)
    }

    method enable {name} {
	if { ! [info exists parts($name)]} { error "control part {$name} does not exist" }
	if {$enabled($name)} { error "control part {$name} is already enabled" }
	set enabled($name) 1
    }

    method disable {name} {
	if { ! [info exists parts($name)]} { error "control part {$name} does not exist" }
	if { ! $enabled($name)} { error "control part {$name} is already disabled" }
	set enabled($name) 0
    }
	
    method list {args} {
	if {$args eq {}} {
	    return [lsort [array names parts]]
	}
	set result {}
	foreach arg $args {
	    lappend result $parts($arg)
	}
	return $result
    }
}
