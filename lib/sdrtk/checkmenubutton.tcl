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

package provide sdrtk::checkmenubutton 1.0.0

package require Tk
package require snit

#
# a menu button that identifies the number of x selected in its label
# and calls back with the selected set when it changes
#
namespace eval ::sdrtk {}

snit::widgetadaptor sdrtk::checkmenubutton {
    
    variable data -array {
	summary {}
	selected {}
    }
    
    option -text -default {} -configuremethod Configure
    option -values -default {} -configuremethod Configure
    option -labels -default {} -configuremethod Configure
    option -defaultselected -default {} -configuremethod Configure
    option -command {}
    option -variable {}

    delegate method * to hull
    delegate option * to hull

    constructor {args} {
	installhull using ttk::menubutton -textvar [myvar data(summary)] -menu $win.m
	$self configure {*}$args
    }
    method {Configure -text} {val} {
	set options(-text) $val
	$self RebuildText
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
    method {Configure -defaultselected} {val} {
	set options(-defaultselected) $val
	set data(selected) $val
	$self SetSelected
    }
    method SetSelected {} {
	foreach v $options(-values) {
	    set data(selected-$v) [expr {[lsearch $data(selected) $v] >= 0}]
	}
	$self RebuildText
    }
    method RebuildText {} {
	set data(summary) [join [list [llength $data(selected)] $options(-text)]]
    }
    method Rebuild {} {
	array unset data selected-*
	destroy $win.m
	menu $win.m -tearoff no
	set values $options(-values)
	set labels $options(-labels)
	foreach v $values l $labels {
	    $win.m add checkbutton -label $l -variable [myvar data(selected-$v)] -command [mymethod Set $v]
	    set data(selected-$v) [expr {[lsearch $data(selected) $v] >= 0}]
	}
	$self RebuildText
    }
    method Set {val} {
	set data(selected) {}
	foreach v $options(-values) {
	    if {$data(selected-$v)} {
		lappend data(selected) $v
	    }
	}
	$self RebuildText
	if {$options(-variable) ne {}} { set $options(-variable) $data(selected) }
	if {$options(-command) ne {}} { {*}$options(-command) $data(selected) }
    }
    # should be tracing the value of $options(-variable)
    method set-selected {selected} {
	set data(selected) $selected
	$self SetSelected
    }
}
