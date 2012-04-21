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
## debounce - key debouncer control
##
package provide sdrui::debounce 1.0.0

package require Tk
package require snit

    
snit::widgetadaptor sdrui::debounce {
    component wperiod
    component period
    component wsteps
    component steps

    option -debounce -default 0 -type snit::boolean
    option -period -default 0.1
    option -steps -default 4
    option -command {}
    option -controls {-steps -period}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install wperiod using ttk::labelframe $win.p -text Period(ms)
	install period using ttk::spinbox $win.p.s -from 0.1 -to 1 -increment 0.1 -textvariable [myvar options(-period)] -command [mymethod set-period]
	install wsteps using ttk::labelframe $win.s -text Steps
	install steps using ttk::spinbox $win.s.s -from 0 -to 64 -increment 1 -textvariable [myvar options(-steps)] -command [mymethod set-steps]
	pack $win.p.s -fill x -expand true
	pack $win.p -fill x -expand true -side top
	pack $win.s.s -fill x -expand true
	pack $win.s -fill x -expand true -side top
	foreach {opt val} { -label {Debounce} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-steps {} { if {$options(-command) ne {}} { {*}$options(-command) report -steps $options(-steps) } }
    method set-period {} { if {$options(-command) ne {}} { {*}$options(-command) report -period $options(-period) } }
}


