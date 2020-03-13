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

    variable n 0
    variable twopi [expr {2*atan2(0,-1)}]
    variable graticule 20
    variable stepsperdiv 1
    
    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure \
	    {*}$args \
	    -integer-to-value [mymethod integer-to-value] \
	    -value-to-integer [mymethod value-to-integer] \
	    -integer-to-phi [mymethod integer-to-phi] \
	    -phi-to-integer [mymethod phi-to-integer]
	set n [llength $options(-values)]
    }
    
    method mapped {} {
	$hull mapped
	[$self cget -dialbook] configure -graticule $graticule
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
	return $i
    }

    method integer-to-value {i} {
	set i [expr {int(round($i))}]
	if {$i < 0 || $i >= [llength $options(-values)]} { error "invalid value $i in readout-enum integer-to-value" }
	return [lindex $options(-values) $i]
    }
    
    method integer-to-phi {i} { return [expr {$i*$twopi/($stepsperdiv*$graticule)}] }

    method phi-to-integer {phi} { return [expr {$stepsperdiv*$graticule*$phi/$twopi}] }

    method {Configure -values} {values} {
	if {[llength $values] == 0} { error "readout-enum: -values has no members" }
	set options(-values) $values
	set n [llength $values]
	set imin 0
	set imax [expr {$n-1}]
	set pmin [$self integer-to-phi $imin]
	set pmax [$self integer-to-phi $imax]
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
	# puts "[$hull cget -text]: $n values "
	$self configure -integer-min $imin -integer-max $imax -phi-min $pmin -phi-max $pmax
    }
}
