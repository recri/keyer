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

package provide sdrtk::iscale 1.0.0

package require Tk
package require snit

namespace eval ::sdrtk {}

##
## a ttk::scale constrained to integer values
## FIX.ME - not finished
##

snit::widgetadaptor sdrtk::iscale {
    
    option -from -default 0 -configuremethod Configure
    option -to -default 0 -configuremethod Configure
    option -step -default 1 -configure Configure
    option -value -default 0 -configure Configure
    option -command -default {} -configure Configure
    option -variable -default {} -configure Configure

    delegate option * to hull
    delegate method * to hull

    variable data {
	value 0
    }

    constructor {args} {
	install hull using ttk::scale -command [mymethod Command] -variable [myvar data(value)]
	$self configure {*}$args
    }

    method Configure {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -from -
	    -to -
	    -value { $hull configure $opt $val }
	    -step -
	    -command {}
	    -variable {
	    }
	}
    }
    method Command {val} {
    }
    method set {val} {
    }
    method get {args} {
    }
}
