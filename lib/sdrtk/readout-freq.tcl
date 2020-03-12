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
# a frequency readout
#

package provide sdrtk::readout-freq 1.0

package require Tk
package require snit
package require sdrtk::readout-value

snit::widgetadaptor sdrtk::readout-freq {
    option -units -default MHz -configuremethod Configure

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::readout-value -dialbook [from args -dialbook {}]
	$self configure -units MHz {*}$args
    }
    
    method {Configure -units} {val} {
	set options(-units) $val
	$hull configure -units $val
	switch $val {
	    Hz { $hull configure -step 1 }
	    kHz { $hull configure -step 1e-3 }
	    MHz { $hull configure -step 1e-6 }
	    GHz { $hull configure -step 1e-9 }
	    THz { $hull configure -step 1e-12 }
	    default { error "unanticipated unit \"$val\"" }
	}
    }
}
