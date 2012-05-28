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

snit::widget sdrtk::readout-value {
    hulltype ttk::labelframe
    component lvalue
    component lunits

    option -value -default 0 -configuremethod Configure
    option -units -default {} -configuremethod Configure
    option -font -default {Helvetica 20} -configuremethod Configure
    option -format -default %f -configuremethod Redisplay
    option -scale -default 1 -configuremethod Redisplay
    option -offset -default 0 -configuremethod Redisplay
    option -step -default 1 -configuremethod Configure
    option -variable -default {} -configuremethod Configure
    option -command {}

    delegate option -text to hull

    variable value 0

    constructor {args} {
	install lvalue using ttk::label $win.value -textvar [myvar value] -width 10 -font $options(-font) -anchor e
	install lunits using ttk::label $win.units -textvar [myvar options(-units)] -width 5 -font $options(-font) -anchor w
	grid $win.value $win.units
	$self configure {*}$args
    }
    
    method adjust {step} {
	$self configure -value [expr {$options(-value)+$step*$options(-step)}]
    }

    method Display {} {
	set value [format $options(-format) [expr {double($options(-value))*$options(-scale)+$options(-offset)}]]
    }

    method Redisplay {opt val} {
	set options($opt) $val
	$self Display
    }

    method {Configure -value} {val} {
	if {$options(-value) != $val} {
	    set options(-value) $val
	    if {$options(-variable) ne {}} { set $options(-variable) $val }
	    if {$options(-command) ne {}} { {*}$options(-command) $val }
	    $self Display
	}
    }

    method {Configure -units} {val} {
	set options(-units) $val
    }
    
    method {Configure -step} {val} {
	set options(-step) $val
	$self configure -value [expr {int($options(-value)/$val)*$val}]
    }

    method {Configure -font} {val} {
	set options(-font) $val
	$lvalue configure -font $val
	$lunits configure -font $val
    }

    method {Configure -variable} {val} {
	if {$options(-variable) ne {}} {
	    trace remove variable $options(-variable) write [mymethod TraceWrite]
	}
	set options(-variable) $val
	if {$options(-variable) ne {}} {
	    trace add variable $options(-variable) write [mymethod TraceWrite]
	    $self TraceWrite
	}
    }
    method TraceWrite {args} { catch { $self configure -value [set $options(-variable)] } }
}