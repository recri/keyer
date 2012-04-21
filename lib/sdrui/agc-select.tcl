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

##
## agc-select - agc mode chooser
##
package provide sdrui::agc-select 1.0.0

package require Tk
package require snit
    
snit::widgetadaptor sdrui::agc-select {
    component menubutton
    component menu

    option -mode -default med -type {snit::enum -values {off long slow med fast}}
    option -command {}
    option -controls {-mode}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install menubutton using ttk::menubutton $win.b -textvar [myvar options(-mode)] -menu $win.b.m
	install menu using menu $win.b.m -tearoff no
	foreach mode {off long slow med fast} {
	    $win.b.m add radiobutton -label $mode -variable [myvar options(-mode)] -value $mode -command [mymethod set-mode $mode]
	}
	pack $win.b -fill x -expand true
	foreach {opt val} { -label {AGC} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-mode {val} { if {$options(-command) ne {}} { {*}$options(-command) report -mode $val } }
}


