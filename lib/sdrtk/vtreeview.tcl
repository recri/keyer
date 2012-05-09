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

package provide sdrtk::vtreeview 1.0.0

package require Tk
package require snit

namespace eval ::sdrtk {}

#
# a treeview with vertical scrollbar to left or right
#
snit::widget sdrtk::vtreeview {
    component treeview
    component scrollbar

    option -scrollbar -default right -type {snit::enum -values {left right}} -configuremethod Configure
    option -scrollnotify {}
    option -width -configuremethod Width

    delegate method * to treeview
    delegate option * to treeview

    constructor {args} {
	install treeview using ttk::treeview $win.t -yscrollcommand [mymethod Scroll set $win.v]
	install scrollbar using ttk::scrollbar $win.v -orient vertical -command [mymethod Scroll yview $win.t]
	$self configure {*}$args
    }

    method {Configure -scrollbar} {side} {
	puts "$self Configure -scrollbar $side"
	set options(-scrollbar) $side
	catch {pack forget $win.t $win.v}
	switch $options(-scrollbar) {
	    left {
		pack $win.t -side right -fill both -expand true
		pack $win.v -side right -fill y
	    }
	    right {    
		pack $win.t -side left -fill both -expand true
		pack $win.v -side left -fill y
	    }
	}
    }
				   
    method bind {pattern command} {
	bind $win.t $pattern $command
    }

    method {Width -width} {val} {
	$treeview column #0 -width $val
    }

    method {Scroll set} {w args} {
	$w set {*}$args
	if {$options(-scrollnotify) ne {}} { {*}$options(-scrollnotify) }
    }

    method {Scroll yview} {w args} {
	$w yview {*}$args
	if {$options(-scrollnotify) ne {}} { {*}$options(-scrollnotify) }
    }
}
 

