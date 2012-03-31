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

package provide sdrblk::iq-swap 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

::snit::type sdrblk::iq-swap {
    component block -public block

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -swap -default false -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "iq-swap $self constructor $args"
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
    }

    destructor {
        $block destroy
    }

    method Validate {opt val} {
	#puts "iq-swap $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof {}
	    -swap {
		::sdrblk::validate::boolean $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    proc swap {port1 port2} { return [list $port2 $port1] }

    method Configure {opt val} {
	#puts "iq-swap $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof {}
	    -swap {
		set val [::sdrblk::validate::get-boolean $val]
		if {$val} {
		    # swap inputs into outputs
		    $block configure -outport [swap {*}[$block cget -inport]]
		} else {
		    # no swap inputs into outputs
		    $block configure -outport [$block cget -inport]
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
