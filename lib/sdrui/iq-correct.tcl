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
package require sdrtk::lradiomenubutton

namespace eval ::sdrui {}

snit::widgetadaptor sdrui::iq-correct {

    option -mu -default 0 -type sdrtype::iq-correct -configuremethod Configure

    option -options {-mu}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    variable data -array {
	labels {0 1/128 1/64 1/32 1/16 1/8 1/4 1/2 1 2 4 8 16 32 64 128}
	values {}
    }

    constructor {args} {
	installhull using sdrtk::lradiomenubutton -label {IQ correct} -labelanchor n

	foreach l $data(labels) { lappend data(values) [expr $l.0] }
	$hull configure -defaultvalue 0 -values $data(values) -labels $data(labels) -command [mymethod Set -mu]

	$self configure {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	switch -exact -- $opt {
	    -mu { $hull set-value $val }
	}
    }

    method Set {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $options($opt)
    }
}


