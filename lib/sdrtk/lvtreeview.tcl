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

package provide sdrtk::lvtreeview 1.0.0

package require Tk
package require snit
package require sdrtk::vtreeview

namespace eval ::sdrtk {}

#
# a labeled treeview with vertical scrollbar to left or right
#
snit::widget sdrtk::lvtreeview {
    hulltype ttk::labelframe
    component treeview

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    delegate method * to treeview
    delegate option * to treeview

    constructor {args} {
	install treeview using sdrtk::vtreeview $win.t
	pack $win.t -fill both -expand true
	$self configure {*}$args
    }
}
 

