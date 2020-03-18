# -*- mode: Tcl; tab-width: 8; -*-
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

#
# a value readout consisting of a labelled frame,
# a value formatted as a text string
# and a unit string displayed in an adjacent label
#
# hah, so you need to update the -values option value 
# when you change the -value option value
#
package provide sdrtk::readout-text 1.0

package require Tk
package require snit
package require sdrtk::readout-core

snit::widgetadaptor sdrtk::readout-text {
    delegate option * to hull
    delegate method * to hull
    constructor {args} {
	installhull using sdrtk::readout-core -dialbook [from args -dialbook {}]
	$self configure -steps-per-div 1 -integer-to-value [mymethod integer-to-value] -value-to-integer [mymethod value-to-integer] {*}$args
    }
    method value-to-integer {val} { return 0 }
    method integer-to-value {i} { return [$hull cget -value] }
    method menu-entry {m text} { return [list command -label $text -state disabled] }
    method button-entry {m text} { return [ttk::label $m -text $text] }
}
