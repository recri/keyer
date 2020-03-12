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
# a value readout consisting of a labelled frame,
# a value possibly scaled and offset formatted into a label,
# and a unit string displayed in an adjacent label
#

package provide sdrtk::readout-value 1.0

package require Tk
package require snit
package require sdrtk::readout-core

snit::widgetadaptor sdrtk::readout-value {
    option -min -default 0 -configuremethod Configure
    option -max -default 0 -configuremethod Configure
    option -step -default 1 -configuremethod Configure
    
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure \
	    -value-to-integer [mymethod value-to-integer] \
	    -integer-to-value [mymethod integer-to-value] \
	    {*}$args
    }
    
    method value-to-integer {value} {
	return [expr {int(($value-$options(-min))/$options(-step))}]
    }

    method integer-to-value {integer} {
	return [expr {$options(-min)+$integer*$options(-step)}]
    }

    method Configure {opt val} {
	set options($opt) $val
	$hull configure \
	    -integer-min [$self value-to-integer $options(-min)] \
	    -integer-max [$self value-to-integer $options(-max)]
    }
	    
}
