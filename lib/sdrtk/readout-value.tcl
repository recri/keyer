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

    variable graticule 20
    variable stepsperdiv 1
    variable twopi [expr {2*atan2(0,-1)}]
    
    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure \
	    {*}$args \
	    -value-to-integer [mymethod value-to-integer] \
	    -integer-to-value [mymethod integer-to-value] \
	    -integer-to-phi [mymethod integer-to-phi] \
	    -phi-to-integer [mymethod phi-to-integer]
    }
    
    method mapped {} {
	$hull mapped
	[$self cget -dialbook] configure -graticule $graticule
    }

    method unmapped {} {
	$hull unmapped
    }
    
    method value-to-integer {value} { return [expr {int(($value-$options(-min))/$options(-step))}] }
    method integer-to-value {integer} { return [expr {$options(-min)+$integer*$options(-step)}] }
    method integer-to-phi {i} { return [expr {$i*$twopi/($stepsperdiv*$graticule)}] }
    method phi-to-integer {phi} { return [expr {int(round($stepsperdiv*$graticule*$phi/$twopi))}] }

    method Configure {opt val} {
	set options($opt) $val
	set imin [$self value-to-integer $options(-min)]
	set imax [$self value-to-integer $options(-max)]
	set pmin [$self integer-to-phi $imin]
	set pmax [$self integer-to-phi $imax]
	set n [expr {$imax-$imin+1}]
	if {$n <= 20} {
	    set graticule 20; set stepsperdiv 1
	} elseif {$n <= 40} {
	    set graticule 20; set stepsperdiv 2
	} elseif {$n <= 80} {
	    set graticule 20; set stepsperdiv 4
	} elseif {$n <= 100} {
	    set graticule 20; set stepsperdiv 5
	} else {
	    set graticule 20; set stepsperdiv 10
	}
	# puts "[$hull cget -text]  $n values"
	$self configure -integer-min $imin -integer-max $imax -phi-min $pmin -phi-max $pmax
    }
	    
}
