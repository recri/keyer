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
package require sdrui::common
package require sdrtype::types
    
snit::widget sdrui::af-gain {
    hulltype ttk::labelframe
    component button
    component spinbox

    option -gain -default 0 -type sdrtype::gain -configuremethod Configure
    option -mute -default 0 -type sdrtype::mute -configuremethod Configure

    option -options {-gain -mute}
    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull
    delegate option * to spinbox
    delegate method * to spinbox

    constructor {args} {
	install button using ttk::checkbutton $win.mute -text Mute -variable [myvar options(-mute)] -command [mymethod Altered -mute]
	install spinbox using ttk::spinbox $win.gain -width 4  -from [sdrtype::gain cget -min] -to [sdrtype::gain cget -max] \
	    -textvar [myvar options(-gain)] -command [mymethod Altered -gain]

	pack $win.mute -side left
	pack $win.gain -side right -fill x -expand true

	$self configure -label {AF gain} -labelanchor n {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} { set options($opt) $val }
    method Altered {opt} { {*}$options(-command) report $opt $options($opt) }
}


