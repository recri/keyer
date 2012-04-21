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
## iq-correct - I/Q channel correction control
##
package provide sdrui::iq-correct 1.0.0

package require Tk
package require snit

    
snit::widgetadaptor sdrui::iq-correct {
    component button

    option -correct -default 0 -type snit::boolean
    option -command {}
    option -controls {-correct}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install button using ttk::checkbutton $win.correct -text correct -variable [myvar options(-correct)] -command [mymethod set-correct]
	pack $win.correct -fill x -expand true
	foreach {opt val} { -label {IQ correct} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-correct {} { if {$options(-command) ne {}} { {*}$options(-command) report -correct $options(-correct) } }
}


