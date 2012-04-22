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

    option -freq -default 10000
    option -command {}
    option -controls {-freq}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option -freq-min to spinbox as -from
    delegate option -freq-max to spinbox as -to
    delegate option -freq-step to spinbox as -increment

    constructor {args} {
	installhull using ttk::labelframe
	install spinbox using ttk::spinbox $win.freq -width 4 -textvar [myvar options(-freq)] -command [mymethod set-freq]
	pack $win.freq -side right -fill x -expand true
	foreach {opt val} { -freq-min -24000 -freq-max 24000 -freq-step 1000 -label {LO freq} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-freq {} { if {$options(-command) ne {}} { {*}$options(-command) report -freq $options(-freq) } }
}


