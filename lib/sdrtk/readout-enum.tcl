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

snit::widget sdrtk::readout-enum {
    hulltype ttk::labelframe
    component lvalue

    option -value -default 0 -configuremethod Configure
    option -values -default {0 1 2 3} -configuremethod Configure
    option -step -default 0.1
    option -font -default {Helvetica 20} -configuremethod Configure
    option -variable -default {} -configuremethod Configure
    option -info -default {} -configuremethod Configure
    option -command {}

    delegate option -text to hull

    variable value 0
    variable pointer 0

    constructor {args} {
	install lvalue using ttk::label $win.value -textvar [myvar value] -width 15 -font $options(-font) -anchor c
	grid $win.value
	$self configure {*}$args
    }
    
    method adjust {step} {
	set n [llength $options(-values)]
	set pointer [expr {fmod($pointer+$step*$options(-step)+$n, $n)}]
	$self configure -value [lindex $options(-values) [expr {int($pointer)}]]
    }

    method Display {} {
	set value $options(-value)
    }

    method Redisplay {opt val} {
	set options($opt) $val
	$self Display
    }

    method {Configure -values} {val} {
	set options(-values) $val
    }

    method {Configure -value} {val} {
	if {$options(-value) ne $val} {
	    set options(-value) $val
	    if {$options(-variable) ne {}} { set $options(-variable) $val }
	    if {$options(-command) ne {}} { {*}$options(-command) $val }
	    $self Display
	}
    }

    method {Configure -step} {val} {
	set options(-step) $val
	$self configure -value [expr {int($options(-value)/$val)*$val}]
    }

    method {Configure -font} {val} {
	set options(-font) $val
	$lvalue configure -font $val
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
    method {Configure -info} {val} {
	set options(-info) $val
    }
    method TraceWrite {args} { catch { $self configure -value [set $options(-variable)] } }
}
