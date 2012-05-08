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
## agc-select - agc mode chooser
##
package provide sdrui::agc-select 1.0.0

package require Tk
package require snit
package require sdrui::common
package require sdrtype::types
package require sdrtk::radiomenubutton

namespace eval ::sdrui {}
    
snit::widget sdrui::agc-select {
    hulltype ttk::labelframe

    option -mode -default med -type sdrtype::agc-mode -configuremethod Configure

    option -options {-mode}
    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	sdrtk::radiomenubutton $win.agc -defaultvalue med -command [mymethod Set -mode] \
	    -values [sdrtype::agc-mode cget -values] \
	    -labels [sdrtype::agc-mode cget -values]

	pack $win.agc -fill x -expand true

	$self configure {*}[sdrui::common::merge $args -label {AGC} -labelanchor n]
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	$win.agc set-value $val
    }
    method Report {opt val} { {*}$options(-command) report $opt $val }
    method Set {opt val} {
	set options($opt) $val
	$self Report $opt $val
    }
}


