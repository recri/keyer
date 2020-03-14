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

    variable twopi [expr {2*atan2(0,-1)}]
    variable tested 0
   
    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure \
	    {*}$args \
	    -value-to-integer [mymethod value-to-integer] \
	    -integer-to-value [mymethod integer-to-value]
    }
    
    method mapped {} {
	$hull mapped
	if {[$self cget -testing] && ! $tested} {
	    set tested 1
	    $self test
	}
    }

    method unmapped {} {
	$hull unmapped
    }
    
    method value-to-integer {value} { return [expr {int(round(($value)/$options(-step)))}] }
    method integer-to-value {integer} { return [expr {$integer*$options(-step)}] }

    method test {} {
	puts "[$hull cget -text] test:"
	for {set v $options(-min)} {$v <= $options(-max)} {set v [expr {$v+$options(-step)}]} {
	    set v [format [$self cget -format] $v]
	    if {$v < $options(-min) || $options(-max) < $v} { puts "fail $v is not in the range" }
	    set i [$self value-to-integer $v]
	    if {$i < [$self cget -integer-min] || [$self cget -integer-max] < $i} { puts "fail int($v) = $i is not in the range" }
	    set p [$self integer-to-phi $i]
	    if {$p < [$self cget -phi-min] || [$self cget -phi-max] < $p} { puts "fail phi(int($v)) = $p is not in the range" }
	    set i2 [$self phi-to-integer $p]
	    if {$i2 != $i} { puts "fail int(phi($v)) = $i2 is not equal to int($v) = $i" }
	    if {$i2 < [$self cget -integer-min] || [$self cget -integer-max] < $i2} { puts "fail int(phi(int($v))) = $i2 is not in the range" }
	    set v2 [format [$self cget -format] [$self integer-to-value $i2]]
	    if {$v2 < $options(-min) || $options(-max) < $v2} { puts "fail int(phi(int($v))) = $v2 is not in the range" }
	    if {$v2 != $v} { puts "fail v = $v != int(phi(int($v))) = $v2" }
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	set imin [$self value-to-integer $options(-min)]
	set imax [$self value-to-integer $options(-max)]
	set pmin [$self integer-to-phi $imin]
	set pmax [$self integer-to-phi $imax]
	$self configure -integer-min $imin -integer-max $imax -phi-min $pmin -phi-max $pmax
    }
	    
}
