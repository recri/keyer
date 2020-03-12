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
    option -variable -default {} -configuremethod Configure
    option -info -default {}

    option -widget-value -default {}

    proc identity {x} { return $x }
    
    option -value-to-integer -default {}
    option -integer-to-value -default {}
    option -integer-to-phi -default {}
    option -phi-to-integer -default {}
    option -integer-min -default 0
    option -integer-max -default 0
    
    option -font -default {Courier 20 bold} -configuremethod Configure
    option -format -default %s -configuremethod Configure
    option -ronly -default 0
    option -volatile -default 0
    option -command -default {}
    option -dialbook -default {} -readonly 1
    
    delegate option -text to hull

    variable value {}

    constructor {args} {
	puts "readout-core constructor $args"
	foreach opt {-value-to-integer -integer-to-value -integer-to-phi -phi-to-integer} { set options($opt) [myproc identity] }
	$self configurelist $args
	install lvalue using ttk::label $win.value -textvar [myvar options(-value)] -width 15 -font $options(-font) -anchor e
	install lunits using ttk::label $win.units -textvar [myvar options(-units)] -width 5 -font $options(-font) -anchor w
	grid $win.value $win.units
	trace add variable options(-widget-value) write [mymethod TraceWriteWidgetValue]
    }
    
    method adjust {step} {
	# convert step
	set di [{*}$options(-phi-to-integer) $step]
	# convert value
	set ci [{*}$options(-value-to-integer) $options(-value)]
	# compute new value as integer
	set newi [expr {min($options(-integer-max), max($options(-integer-min), $ci+$di))}]
	set newv [{*}$options(-integer-to-value) $newi]
	if {$newv ne $options(-value)} { $self configure -value $newv }
    }
    method value {} { return $options(-value) }
    method value-var {} { return [myvar option(-value)] }
    method widget-value-var {} { return [myvar option(-widget-value)] }
    method menu-entry {w text} { return {} }
    method button-entry {w text} { return {} }

    variable saved
    method mapped {} {
	set saved {}
	foreach o {-detents -detent-min -detent-max -graticule -phi} {
	    lappend saved $o [$options(-dialbook) cget $o]
	}
    }
    method unmapped {} {
	$options(-dialbook) configure {*}$saved
    }

    method {Configure -value} {val} {
	set val [format $options(-format) $val]
	if {$options(-value) != $val} {
	    set options(-value) $val
	    if {$options(-variable) ne {}} { set $options(-variable) $val }
	    if {$options(-command) ne {}} { {*}$options(-command) $val }
	    set i [{*}$options(-value-to-integer) $val]
	    if {[regexp {^\d+$} $i]} {
		set p [{*}$options(-integer-to-phi) $i]
		puts "setting dialbook phi to {$p} computed from {$i} and from $val"
		{*}$options(-dialbook) configure -phi $p
	    }
	}
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
	    $self TraceWriteVariable
	}
    }
    method TraceWriteVariable {args} { catch { $self configure -value [set $options(-variable)] } }
    method TraceWriteWidgetValue {args} { catch { $self configure -value $options(-widget-value) } }
}
