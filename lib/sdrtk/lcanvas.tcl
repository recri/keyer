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

package provide sdrtk::lcanvas 1.0.0

package require Tk
package require snit

namespace eval ::sdrtk {}

##
## a canvas in a labelled frame
## scrolled under control of manager
## in sync with panels to either side
##

snit::widget sdrtk::lcanvas {
    hulltype ttk::labelframe
    component canvas
    
    option -container {}

    delegate option -text to hull
    delegate option -labelanchor to hull
    
    delegate option * to canvas
    delegate method * to canvas

    constructor {args} {
	install canvas using canvas $win.c
	pack $canvas -fill both -expand true
	$self configure {*}$args
    }

    method bind {pattern command} {
	bind $canvas $pattern $command
    }
}
