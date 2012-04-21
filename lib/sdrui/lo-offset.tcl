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
## lo-offset - local oscillator offset in rx and tx
##
package provide sdrui::lo-offset 1.0.0

package require Tk
package require snit

snit::widgetadaptor sdrui::lo-offset {
    component spinbox

    option -offset -default 10000
    option -command {}
    option -controls {-offset}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option -offset-min to spinbox as -from
    delegate option -offset-max to spinbox as -to
    delegate option -offset-step to spinbox as -increment

    constructor {args} {
	installhull using ttk::labelframe
	install spinbox using ttk::spinbox $win.offset -width 4 -textvar [myvar options(-offset)] -command [mymethod set-offset]
	pack $win.offset -side right -fill x -expand true
	foreach {opt val} { -offset-min -24000 -offset-max 24000 -offset-step 1000 -label {LO offset} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-offset {} { if {$options(-command) ne {}} { {*}$options(-command) report -offset $options(-offset) } }
}


