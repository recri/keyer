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
## iq-correct - I/Q channel correction control
##
package provide sdrui::iq-correct 1.0.0

package require Tk
package require snit

package require sdrui::common
package require sdrtype::types
package require sdrtk::radiomenubutton

namespace eval ::sdrui {}

snit::widget sdrui::iq-correct {
    hulltype ttk::labelframe

    option -mu -default 0 -type sdrtype::iq-correct -configuremethod Configure

    option -options {-mu}
    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {

	set values {}
	set labels {}
	foreach v {0 1/128 1/64 1/32 1/16 1/8 1/4 1/2 1 2 4 8 16 32 64 128} {
	    lappend labels $v
	    lappend values [expr $v.0]
	}

	sdrtk::radiomenubutton $win.correct -defaultvalue 0 -command [mymethod Set -mu] -values $values -labels $labels
	pack $win.correct -fill x -expand true

	$self configure {*}[sdrui::common::merge $args -label {IQ correct} -labelanchor n]

    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	switch -exact -- $opt {
	    -mu { $win.correct set-value $val }
	}
    }

    method Set {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $options($val)
    }
}


