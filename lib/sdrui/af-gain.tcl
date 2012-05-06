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
## af-gain - af-gain control for agc off
##
package provide sdrui::af-gain 1.0.0

package require Tk
package require snit

    
snit::widget sdrui::af-gain {
    hulltype ttk::labelframe
    component button
    component spinbox

    option -gain -default 0
    option -mute -default 0

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option -gain-min to spinbox as -from
    delegate option -gain-max to spinbox as -to
    delegate option -gain-step to spinbox as -increment

    constructor {args} {
	install button using ttk::checkbutton $win.mute -text Mute -variable [myvar options(-mute)] -command [mymethod set-mute]
	install spinbox using ttk::spinbox $win.gain -width 4 -textvar [myvar options(-gain)] -command [mymethod set-gain]
	pack $win.mute -side left
	pack $win.gain -side right -fill x -expand true
	foreach {opt val} { -gain-min -100 -gain-max 200 -gain-step 1 -label {AF gain} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-gain -mute} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }

    method set-gain {} { {*}$options(-command) report -gain $options(-gain) }
    method set-mute {} { {*}$options(-command) report -mute $options(-mute) }
}


