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

package provide sdrtk::radiomenubutton 1.0.0

package require Tk
package require snit

#
# a radio menu button that identifies its value on its label
# but reports a possibly different set of values when a label
# is selected
#
namespace eval ::sdrtk {}

snit::widgetadaptor sdrtk::radiomenubutton {
    
    variable data -array {
	label {}
    }
    
    option -values -default {} -configuremethod Configure
    option -labels -default {} -configuremethod Configure
    option -defaultvalue -default {} -configuremethod Configure
    option -command {}
    option -variable {}

    delegate method * to hull
    delegate option * to hull

    constructor {args} {
	installhull using ttk::menubutton -textvar [myvar data(label)] -menu $win.m
	$self configure {*}$args
    }
    
    method {Configure -values} {val} {
	set options(-values) $val
	if {[llength $val] ne [llength $options(-labels)]} { set options(-labels) $val }
	$self Rebuild
    }
    method {Configure -labels} {val} {
	set options(-labels) $val
	if {[llength $val] ne [llength $options(-values)]} { set options(-values) $val }
	$self Rebuild
    }
    method {Configure -defaultvalue} {val} {
	set options(-defaultvalue) $val
    }
    method Rebuild {} {
	set values $options(-values)
	set labels $options(-labels)
	array unset data
	destroy $win.m
	menu $win.m -tearoff no
	set data(label) [lindex $labels 0]
	foreach v $values l $labels {
	    $win.m add radiobutton -label $l -value $l -variable [myvar data(label)] -command [mymethod Set $v]
	    set data(value-$l) $v
	    set data(label-$v) $l
	}
	if {[info exists data(label-$options(-defaultvalue))]} {
	    set data(label) $data(label-$options(-defaultvalue))
	}
    }

    method Set {val} {
	if {$options(-variable) ne {}} { set $options(-variable) $val }
	if {$options(-command) ne {}} { {*}$options(-command) $val }
    }

    # should be tracing the value of $options(-variable)
    method set-value {val} {
	set data(label) $data(label-$val)
    }
}
