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
# a value readout consisting of a labelled frame
# handling the core of reading out a value
# so it can be a component of more complex readouts
#

#
# okay, so the key to the dial is that every option can be mapped
# onto a sequence of numbers, which can in turn be mapped onto a
# sequence of position angles for the dial.
#
# The confusion comes when the sequence of numbers is not directly
# the value displayed or chosen.
#
# So an arbitrary enum is a list of values, and the sequence of numbers
# are the indexes of the values in the list, and the sequence of angles
# is chosen to fill the circle, or fill a segment, or something.
#
# So we have the range of values, which could be a list of words, or a list
# of numbers, or an implicit list of numbers defined as a bounded range.
# Then we have a map which converts the range of values into the range of
# integers which the dial selects, and then there is the range of angles
# which is probably a direct map.
#
# Then we have the inverse maps which translate dial motion and positioning
# back into the values.
#
# so, is there a core readout which answers all of these needs?
#
package provide sdrtk::readout-core 1.0

package require Tk
package require snit

snit::widget sdrtk::readout-core {
    hulltype ttk::labelframe
    component lvalue
    component lunits

    option -value -default 0 -configuremethod Configure
    option -units -default {}
    option -graticule -default 20 -configuremethod Recompute
    option -steps-per-div -default 5 -configuremethod Recompute
    option -variable -default {} -configuremethod Configure
    option -info -default {}

    option -widget-value -default {}

    option -value-to-integer -default {}
    option -integer-to-value -default {}

    option -integer-min -default 0 -configuremethod Recompute
    option -integer-max -default 0 -configuremethod Recompute
    option -phi-min -default 0 -readonly 1
    option -phi-max -default 0 -readonly 1
    
    option -font -default {Courier 20 bold} -configuremethod Configure
    option -format -default %s -configuremethod Configure
    option -ronly -default 0
    option -volatile -default 0
    option -command -default {}
    option -dialbook -default {} -readonly 1
    
    delegate option -text to hull

    proc identity {x} { return $x }
    
    variable twopi [expr {2*atan2(0,-1)}]
    variable saved {}
    variable steps 0
    variable ismapped 0

    constructor {args} {
	#puts "readout-core constructor $args"
	#  -integer-to-phi -phi-to-integer
	foreach opt {-value-to-integer -integer-to-value} { set options($opt) [myproc identity] }
	$self configurelist $args
	install lvalue using ttk::label $win.value -textvar [myvar options(-value)] -width 15 -font $options(-font) -anchor e
	install lunits using ttk::label $win.units -textvar [myvar options(-units)] -width 5 -font $options(-font) -anchor w
	grid $win.value $win.units
	trace add variable options(-widget-value) write [mymethod TraceWriteWidgetValue]
    }
    
    # translate step, we accumulate steps since last explicit set of -phi
    # so we know where the pointer is pointing
    method adjust {step} {
	incr steps $step
	# rotate to positive radians
	set phi [expr {[$options(-dialbook) cget -phi]+$twopi*$steps/[$options(-dialbook) cget -cpr]}]
	# enforce bounds, translate to value
	# puts "[$hull cget -text] $options(-integer-min) $options(-integer-max)"
	if {$phi < $options(-phi-min)} {
	    set v [{*}$options(-integer-to-value) $options(-integer-min)]
	    set enforce 1
	} elseif {$phi > $options(-phi-max)} {
	    set v [{*}$options(-integer-to-value) $options(-integer-max)]
	    set enforce 1
	} else {
	    set v [{*}$options(-integer-to-value) [$self phi-to-integer $phi]]
	    set enforce 0
	}
	# apply the format
	set v [format $options(-format) $v]
	# take a quick roundtrip 
	# and alter the value if necessary
	if {[$self valid-value $v] && ($v ne $options(-value) || $enforce)} { 
	    $self configure -value $v
	}
    }

    method valid-value {val} {
	return [expr {$val eq [format $options(-format) [{*}$options(-integer-to-value) [{*}$options(-value-to-integer) $val]]]}]
    }

    # method value {} { return $options(-value) }
    # method value-var {} { return [myvar option(-value)] }
    method widget-value-var {} { return [myvar option(-widget-value)] }

    method integer-to-phi {i} { return [expr {$i*$twopi/($options(-steps-per-div)*$options(-graticule))}] }
    method phi-to-integer {phi} { return [expr {$options(-steps-per-div)*$options(-graticule)*$phi/$twopi}] }

    method mapped {} {
	# puts "readout-core mapped [$hull cget -text]"
	set ismapped 1
	set saved [list -graticule [$options(-dialbook) cget -graticule] -phi [$options(-dialbook) cget -phi]]
	$options(-dialbook) configure -graticule $options(-graticule)
	$self Position
    }
    method unmapped {} {
	#puts "readout-core unmapped [$hull cget -text]"
	set ismapped 0
	$options(-dialbook) configure {*}$saved
    }
    method Position {} {
	if { ! $ismapped } return
	set i [{*}$options(-value-to-integer) $options(-value)]
	if {[string is integer $i]} {
	    set p [$self integer-to-phi $i]
	    # puts "setting dialbook phi to {$p} computed from {$i}, computed from {$options(-value)}, for [$hull cget -text]"
	    $options(-dialbook) configure -phi $p
	    # puts "configured -phi $p, [$options(-dialbook) cget -phi]"
	    set steps 0
	} else {
	    after 1 [mymethod Position]
	}
    }
	
    method {Configure -value} {val} {
	set val [format $options(-format) $val]
	if {$options(-value) != $val} {
	    set options(-value) $val
	    if {$options(-variable) ne {}} { set $options(-variable) $val }
	    if {$options(-command) ne {}} { {*}$options(-command) $val }
	}
	$self Position
    }
    method {Configure -widget-value} {val} { set options(-widget-value) $val }
    method {Configure -format} {val} {
	set options(-format) $val
	#$self configure -value $options(-value)
    }
    method {Configure -font} {val} {
	set options(-font) $val
	$lvalue configure -font $val
	$lunits configure -font $val
    }
    method {Configure -variable} {val} {
	if {$options(-variable) ne {}} {
	    trace remove variable $options(-variable) write [mymethod TraceWriteVariable]
	}
	set options(-variable) $val
	if {$options(-variable) ne {}} {
	    trace add variable $options(-variable) write [mymethod TraceWriteVariable]
	    set $options(-variable) [set $options(-variable)]
	}
    }
    method {Recompute} {opt val} { 
	set options($opt) $val
	set options(-phi-min) [$self integer-to-phi $options(-integer-min)]
	set options(-phi-max) [$self integer-to-phi $options(-integer-max)]
    }
 
    method TraceWriteVariable {name1 name2 op} { 
	upvar ${name1}($name2) value
	$self configure -value $value
    }
    method TraceWriteWidgetValue {name1 name2 op} { 
	upvar ${name1}($name2) value
	$self configure -value $value
    }

    method menu-entry {w text} { return {} }
    method button-entry {w text} { return {} }

}
