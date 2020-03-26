# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
# a boolean value readout
#

package provide sdrtk::readout-bool 1.0

package require Tk
package require snit
package require sdrtk::readout-enum

snit::widgetadaptor sdrtk::readout-bool {
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::readout-enum {*}$args -values {0 1}
    }

    method menu-entry {m text} {
	return [list checkbutton -label $text -variable [$self widget-value-var]]
    }

    method button-entry {m text} {
	return [ttk::checkbutton $m -text $text -variable [$self widget-value-var]]
    }

}
