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

package provide sdrui::ui-notebook 1.0.0

package require Tk
package require snit
package require tkcon

package require sdrui::ui-radio-panel
package require sdrui::tree
package require sdrui::connections
package require sdrui::spectrum
package require sdrui::components

# not a notebook anymore

snit::type sdrui::ui-notebook {

    variable data -array {
	tree 0
	port-connections 0
	opt-connections 0
	console 0
	spectrum 0
    }

    option -container -readonly yes
    option -control -readonly yes
    option -name {}
    
    constructor {args} {
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	menu .menu -tearoff no
	foreach label {file edit view} {
	    .menu add cascade -label $label -menu .menu.$label
	    menu .menu.$label -tearoff no
	    if {$label eq {view}} {
		foreach view {spectrum tree connections console} {
		    .menu.view add command -label $view -command [mymethod view $view]
		}
	    }
	}
	. configure -menu .menu
	pack [sdrui::ui-radio-panel .radio -container $self -control $options(-control)] -fill both -expand true
    }

    method view {window} {
	switch $window {
	    console {
		tkcon show
		tkcon title sdrkit:console
	    }
	    default {
		if { ! [winfo exists .$window]} {
		    toplevel .$window
		    pack [$window .$window.t -container $self -control $options(-control)] -fill both -expand true
		    wm title .$window sdrkit:$window
		} else {
		    wm deiconify .$window
		}
	    }
	}
    }
	
    method repl {} { }

}
