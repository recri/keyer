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

package require sdrtype::types
package require sdrtk::lspinbox

snit::widget sdrui::debounce {
    hulltype ttk::labelframe
    component period
    component steps

    option -debounce -default 0 -type sdrtype::debounce
    option -period -default 0.1 -type sdrtype::debounce-period
    option -steps -default 4 -type sdrtype::debounce-steps

    option -options {-debounce -period -steps}
    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	install debounce using ttk::checkbutton $win.d -text Enable -variable [myvar options(-debounce)] -command [mymethod Set -debounce]
	install period using sdrtk::lspinbox $win.p -label Period(ms) -from 0.1 -to 1 -increment 0.1 -width 4 -textvariable [myvar options(-period)] -command [mymethod Set -period]
	install steps using sdrtk::lspinbox $win.s -label Steps -from 0 -to 64 -increment 1 -width 4 -textvariable [myvar options(-steps)] -command [mymethod Set -steps]

	pack $win.d -fill x -expand true -side left
	pack $win.p -fill x -expand true -side left
	pack $win.s -fill x -expand true -side left

	$self configure {*}[::sdrui::common::merge $args -label {Debounce} -labelanchor n]
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Set {opt args} { {*}$options(-command) report $opt $options($opt) }
}


