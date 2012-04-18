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

package provide sdrblk::radio-ui-notebook 1.0.0

package require Tk
package require snit
package require tkcon

package require sdrblk::ui-radio
package require sdrblk::ui-tree
package require sdrblk::ui-connections
package require sdrblk::ui-panadapter

# not a notebook anymore

snit::type sdrblk::radio-ui-notebook {

    variable data -array {
	tree 0
	connections 0
	console 0
	spectrum 0
    }

    option -partof -readonly yes
    option -control -readonly yes
    
    constructor {args} {
	$self configure {*}$args
	set options(-control) [$options(-partof) cget -control]
	menu .menu -tearoff no
	.menu add cascade -label File -menu .menu.file
	menu .menu.file -tearoff no
	.menu add cascade -label Edit -menu .menu.edit
	menu .menu.edit -tearoff no
	.menu add cascade -label View -menu .menu.view
	menu .menu.view -tearoff no
	foreach view {panadapter tree connections console} {
	    .menu.view add checkbutton -label $view -variable [myvar data($view)] -command [mymethod view $view]
	}
	. configure -menu .menu
	pack [sdrblk::ui-radio .radio -partof $self -control $options(-control)] -fill both -expand true
    }

    method widget {foo} {
    }

    method view {window} {
	switch $window {
	    console {
		if {$data(console)} {
		    tkcon show
		    tkcon title sdrkit:console
		} else {
		    tkcon hide
		}
	    }
	    default {
		if { ! [winfo exists .$window]} {
		    toplevel .$window
		    pack [ui-$window .$window.t -partof $self -control $options(-control)] -fill both -expand true
		    wm withdraw .$window
		    wm title .$window sdrkit:$window
		}
		if {$data($window)} {
		    wm deiconify .$window
		} else {
		    wm withdraw .$window
		}
	    }
	}
    }
	
    method repl {} { }

}
