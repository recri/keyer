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

    component myblock

    option -swap -default false -validateMethod Validate -configuremethod Configure

    constructor {args} {
	install myblock 
        $self configure {*}$args
    }

    destructor {
        catch {$tail destroy}
    }

    method Validate {opt val} {
	switch -- $opt {
	    -swap {
		::sdrblk::validate::boolean $opt $val
	    }
	    default {
		error "unknown option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	if {$val} {
	} else {
	}
	set options($opt) $val
    }
}
