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
    
    option -values {}
    option -labels {}
    option -defaultvalue {}
    option -command {}

    delegate method * to hull
    delegate option * to hull

    constructor {args} {
	installhull using ttk::menubutton -textvar [myvar data(label)] -menu $win.m
	$self configure {*}$args
	menu $win.m -tearoff no
	set values $options(-values)
	set labels $options(-labels)
	if {$values eq {} && $labels ne {}} { set values $labels }
	if {$values ne {} && $labels eq {}} { set labels $values }
	if {[llength $values] != [llength $labels]} { error "different numbers of values and labels" }
	set data(label) [lindex $labels 0]
	foreach v $values l $labels {
	    $win.m add radiobutton -label $l -value $l -variable [myvar data(label)] -command [list {*}$options(-command) $v]
	    if {$v eq $options(-defaultvalue)} { set data(label) $l }
	    set data(value-$l) $v
	    set data(label-$v) $l
	}
    }
    
    method set-value {val} {
	set data(label) $data(label-$val)
    }
}
