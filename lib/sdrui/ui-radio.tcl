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

package provide sdrui::ui-radio 1.0.0

package require Tk
package require snit
package require sdrui::ui-radio-panel
package require sdrui::spectrum

snit::type sdrui::ui-radio {

    option -container -readonly yes
    option -control -readonly yes
    option -name {}
    
    constructor {args} {
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	pack [sdrui::ui-radio-panel .radio -container $self -control $options(-control)] -fill both -expand true
	sdrui::spectrum .spectrum -container $self -control $options(-control)
	wm title . sdrkit:radio
	bind . <Destroy> [mymethod window-destroy %W]
    }

    method window-destroy {w} {
	if {$w eq {.}} {
	    #puts "$self window-destroy $w"
	    #puts "$options(-container) destroy"
	    $options(-container) destroy
	}
    }

    destructor {
    }

    method activate {} {}
    method deactivate {} {}

    method resolve {} {
	#$win.panel resolve
	.spectrum resolve
    }

    method repl {} { }

}
