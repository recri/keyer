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

package provide sdrblk::hw 1.0.0

package require snit


::snit::type sdrblk::hw {

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -hw -readonly yes -validatemethod Validate -configuremethod Configure
    
    constructor {args} {
	puts "hw $self constructor $args"
	$self configure {*}$args
    }

    destructor {
    }

    method Validate {opt val} {
	#puts "hw $self Validate $opt $val"
	switch -- $opt {
	    -hw -
	    -partof {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "hw $self Configure $opt $val"
	switch -- $opt {
	    -hw {
	    }
	    -partof {}
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
