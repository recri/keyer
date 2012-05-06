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
## rf-gain - rf-gain control
##
package provide sdrui::rf-gain 1.0.0

package require Tk
package require snit

    
snit::widgetadaptor sdrui::rf-gain {
    component spinbox

    option -gain -default 0 -type sdrtype::gain

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option -gain-min to spinbox as -from
    delegate option -gain-max to spinbox as -to
    delegate option -gain-step to spinbox as -increment

    constructor {args} {
	installhull using ttk::labelframe
	install spinbox using ttk::spinbox $win.gain -width 4 -textvar [myvar options(-gain)] -command [mymethod set-gain]
	pack $win.gain -side right -fill x -expand true
	foreach {opt val} { -gain-min -100 -gain-max 200 -gain-step 1 -label {RF Gain} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-gain} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }

    method set-gain {} { {*}$options(-command) report -gain $options(-gain) }

}


