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
package require sdrtype::types
    
snit::widget sdrui::iq-balance {
    hulltype ttk::labelframe
    component sinephase
    component lineargain

    option -sine-phase -default 0 -type sdrtype::sine-phase
    option -linear-gain -default 1.0 -type sdrtype::linear-gain

    option -options {-sine-phase -linear-gain}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	install sinephase using ttk::spinbox $win.sinephase -from -1 -to 1 -increment 0.001 -width 6 \
	    -textvariable [myvar options(-sine-phase)] -command [mymethod Set -sine-phase]
	install lineargain using ttk::spinbox $win.lineargain -from 0.25 -to 4 -increment 0.001 -width 6 \
	    -textvariable [myvar options(-linear-gain)] -command [mymethod Set -linear-gain]

	pack $win.sinephase -side top -fill x -expand true
	pack $win.lineargain -side top -fill x -expand true

	$self configure -label {IQ balance } -labelanchor n {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} { set options($opt) $val }
    method Set {opt} { {*}$options(-command) report $opt $options($opt) }
}


