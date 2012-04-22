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
## cw-pitch - tune the CW pitch used
## this is the filter center offset on receive
## and the side tone on transmit
##
package provide sdrui::cw-pitch 1.0.0

package require Tk
package require snit

    
snit::widgetadaptor sdrui::cw-pitch {
    component button
    component spinbox

    option -freq 600
    option -spot 0
    option -command {}
    option -controls {-freq -spot}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option -pitch-min to spinbox as -from
    delegate option -pitch-max to spinbox as -to
    delegate option -pitch-step to spinbox as -increment

    constructor {args} {
	installhull using ttk::labelframe
	install button using ttk::checkbutton $win.spot -text Spot -variable [myvar options(-spot)] -command [mymethod set-spot]
	install spinbox using ttk::spinbox $win.pitch -width 3 -textvar [myvar options(-pitch)] -command [mymethod set-pitch]
	pack $win.spot -side left
	pack $win.pitch -side right -fill x -expand true
	foreach {opt val} { -pitch-min 300 -pitch-max 900 -pitch-step 10 -label {CW Pitch} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-pitch {} { if {$options(-command) ne {}} { {*}$options(-command) report -freq $options(-pitch) } }
    method set-spot {args} { if {$options(-command) ne {}} { {*}$options(-command) report -spot $options(-spot) } }

}


