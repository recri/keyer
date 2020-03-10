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

package provide sdrtk::readout 1.0

package require Tk
package require snit

snit::widget sdrtk::readout {
    hulltype ttk::labelframe
    component lvalue
    component lunits

    option -value -default 0 -configuremethod Configure
    option -units -default {}
    option -font -default {Helvetica 20} -configuremethod Configure
    option -format -default %f -configuremethod Configure
    option -variable -default {} -configuremethod Configure
    option -info -default {}
    option -ronly -default 0
    option -volatile -default 0
    option -command {}
    
    delegate option -text to hull

    variable value {}

    constructor {args} {
	$self configure {*}$args
	install lvalue using ttk::label $win.value -textvar [myvar options(-value)] -width 15 -font $options(-font) -anchor e
	install lunits using ttk::label $win.units -textvar [myvar options(-units)] -width 5 -font $options(-font) -anchor w
	grid $win.value $win.units
    }
    
    method menu-entry {w text} { return {} }
    method button-entry {w text} { return {} }
    
    method {Configure -value} {val} {
	set val [format $options(-format) $val]
	if {$options(-value) != $val} {
	    set options(-value) $val
	    if {$options(-variable) ne {}} { set $options(-variable) $val }
	    if {$options(-command) ne {}} { {*}$options(-command) [format $options(-format) $val] }
	}
    }
    method {Configure -format} {val} {
	set options(-format) $val
	$self configure -value $options(-value)
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
	    $self TraceWrite
	}
    }
    method TraceWriteVariable {args} { catch { $self configure -value [set $options(-variable)] } }
}
