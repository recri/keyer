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
# a color value readout consisting of a labelled frame,
# a color value chosen from a list,
# potentially augmentable by command line option
# or from color picker
#

package provide sdrtk::readout-color 1.0

package require Tk
package require snit
package require sdrtk::readout-core

snit::widgetadaptor sdrtk::readout-color {
    option -values -default {} -configuremethod Configure

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure -steps-per-div 1 -integer-to-value [mymethod integer-to-value] -value-to-integer [mymethod value-to-integer] {*}$args
    }
    
    method value-to-integer {val} {
	set i [lsearch -exact $options(-values) $val]
	if {$i < 0} { 
	    lappend options(-values) $val
	    return [value-to-integer $val]
	}
	return $i
    }

    method integer-to-value {i} {
	set i [expr {int(round($i))}]
	if {$i < 0 || $i >= [llength $options(-values)]} { error "invalid value $i in readout-enum integer-to-value" }
	return [lindex $options(-values) $i]
    }
    
    method {Configure -values} {values} {
	if {[llength $values] == 0} { error "readout-enum: -values has no members" }
	set options(-values) $values
	set imin 0
	set imax [expr {[llength $values]-1}]
	$self configure -integer-min $imin -integer-max $imax
	after idle [mymethod CheckGraticule]
    }

    method CheckGraticule {} {
	set v [$self cget -values]
	set g [$self cget -graticule]
	set u [$self cget -graticule-used]
	if {$u == 0} { set u $g }
	set n [llength $v]
	foreach x {12 20 24 36} {
	    if {$n <= $x} {
		$self configure -graticule-used $n -graticule $x -steps-per-div 1
		return
	    }
	}
	puts "readout-enum $self configure -values #$n > $u/$g"
    }

    method menu-entry {m text} {
	if { ! [winfo exists $m]} {
	    menu $m -tearoff no -font {Helvetica 12 bold}
	} else {
	    $m delete 0 end
	}
	foreach v $options(-values) {
	    $m add radiobutton -label $v -value $v -variable [$self widget-value-var]
	}
	return [list cascade -label $text -menu $m]
    }

    method button-entry {m text} {
	ttk::menubutton $m -text $text
	if { ! [winfo exists $m.m]} {
	    menu $m.m -tearoff no -font {Helvetica 12 bold}
	} else {
	    $m.m delete 0 end
	}
	$m configure -menu $m.m
	set i 0
	foreach v $options(-values) {
	    $m.m add radiobutton -label $v -value $v -variable [$self widget-value-var] -columnbreak [expr {($i%10)==0}]
	    incr i
	}
	return $m
    }

    method test {} {
	puts "[$hull cget -text] test:"
	foreach {v o} {imin -integer-min imax -integer-max pmin -phi-min pmax -phi-max} {
	    set $v [$self cget $o]
	}
	foreach v $options(-values) {
	    if {[lsearch $options(-values) $v] < 0} { puts "fail $v is not in {$options(-values)}" }
	    set i [$self value-to-integer $v]
	    if {$i < $imin || $imax < $i} { puts "fail int($v) = $i is not in the range $imin .. $imax" }
	    set p [$self integer-to-phi $i]
	    if {$p < $pmin || $pmax < $p} { puts "fail phi(int($v)) = $p is not in the range $pmin .. $pmax" }
	    set i2 [expr {int(round([$self phi-to-integer $p]))}]
	    if {$i2 != $i} { puts "fail int(phi(int($v))) = $i2 is not equal to int($v) = $i" }
	    if {$i2 < $imin || $imax < $i2} { puts "fail int(phi(int($v))) = $i2 is not in the range $imin $imax" }
	    set v2 [$self integer-to-value $i2]
	    if {$v2 ne $v} { puts "fail val(int(phi(int($v)))) = $v2 is not equal to $v" }
	}
    }

}
