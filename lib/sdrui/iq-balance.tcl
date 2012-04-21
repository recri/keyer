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
## iq-balance - I/Q channel balance control
##
package provide sdrui::iq-balance 1.0.0

package require Tk
package require snit

    
snit::widgetadaptor sdrui::iq-balance {
    component rotation
    component level

    option -rotation -default 0
    option -level -default 0
    option -command {}
    option -controls {-rotation -level}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install rotation using ttk::spinbox $win.rotation -from 0 -to 1 -increment 0.0001 -textvariable [myvar options(-rotation)] -command [mymethod set-rotation]
	install level using ttk::spinbox $win.level -from 0 -to 1 -increment 0.0001 -textvariable [myvar options(-level)] -command [mymethod set-level]
	pack $win.rotation -side top -fill x -expand true
	pack $win.level -side top -fill x -expand true
	foreach {opt val} { -label {IQ balance } -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-rotation {} { if {$options(-command) ne {}} { {*}$options(-command) report -rotation $options(-rotation ) } }
    method set-level {} { if {$options(-command) ne {}} { {*}$options(-command) report -level $options(-level ) } }
}


