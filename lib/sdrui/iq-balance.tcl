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
    component sinephase
    component lineargain

    option -sine-phase -default 0
    option -linear-gain -default 0
    option -command {}
    option -controls {-sine-phase -linear-gain}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install sinephase using ttk::spinbox $win.sinephase -from -1 -to 1 -increment 0.001 -width 6 -textvariable [myvar options(-sine-phase)] -command [mymethod set-sine-phase]
	install lineargain using ttk::spinbox $win.lineargain -from 0.25 -to 4 -increment 0.001 -width 6 -textvariable [myvar options(-linear-gain)] -command [mymethod set-linear-gain]
	pack $win.sinephase -side top -fill x -expand true
	pack $win.lineargain -side top -fill x -expand true
	foreach {opt val} { -label {IQ balance } -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-sine-phase {} { if {$options(-command) ne {}} { {*}$options(-command) report -sine-phase $options(-sine-phase) } }
    method set-linear-gain {} { if {$options(-command) ne {}} { {*}$options(-command) report -linear-gain $options(-linear-gain) } }
}


