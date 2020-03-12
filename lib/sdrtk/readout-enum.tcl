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
# a value chosen from a list,
# and a unit string displayed in an adjacent label
#

package provide sdrtk::readout-enum 1.0

package require Tk
package require snit
package require sdrtk::readout-core

snit::widgetadaptor sdrtk::readout-enum {
    option -values -default {} -configuremethod Configure

    delegate option * to hull
    delegate method * to hull

    variable saved
    
    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configurelist $args
    }
    
    method adjust {step} {
	set v [$self cget -value]
	set i [lsearch -exact $options(-values) $v]
	if {$i < 0} { error "readout-enum value $v is not in values $options(-values)" }
	set n [llength $options(-values)]
	set p [expr {min($n-1,max(0,$i+$step))}]
	$self configure -value [lindex $options(-values) $p]
    }

    method mapped {} {
	# puts "readout-enum mapped"
	$hull mapped
	set n [llength $options(-values)]
	set i [lsearch $options(-values) [$self cget -value]]
	[$self cget -dialbook] configure -detents $n -detent-min 0 -detent-max [expr {$n-1}] -graticule $n -phi [expr {$i*2*3.1416/$n}]
    }

    method unmapped {} {
	$hull unmapped
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

    method value-to-integer {val} {
	set i [lsearch -exact $options(-values) $val]
	if {$i < 0} { error "invalid value $val in readout-enum value-to-integer" }
	return i
    }

    method integer-to-value {i} {
	if {$i < 0 || $i >= [llength $options(-values)]} { error "invalid value $i in readout-enum integer-to-value" }
	return [lindex $options(-values) $i]
    }
    
    method {Configure -values} {values} {
	if {[llength $values] == 0} { error "readout-enum: -values has no members" }
	set options(-values) $values
	set args {}
	$self configure -integer-min 0 \
	    -integer-max [expr {[llength $values]-1}] \
	    -integer-to-value [mymethod integer-to-value] \
	    -value-to-integer [mymethod value-to-integer]
    }
}
