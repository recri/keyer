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
## filter-select - band pass filter chooser
##
package provide sdrui::mode-select 1.0.0

package require Tk
package require snit
package require sdrui::ui-types
    
snit::widgetadaptor sdrui::mode-select {
    
    # second copy of list below, perhaps define an external snit::type for it
    option -mode -default CWU -type sdrui::mode
    option -command {}
    option -controls {-mode}

    constructor {args} {
	installhull using ttk::labelframe -text Mode -labelanchor n
	pack [ttk::menubutton $win.b -textvar [myvar options(-mode)] -menu $win.b.m] -fill x -expand true
	menu $win.b.m -tearoff no
	foreach mode [sdrui::mode cget -values] {
	    $win.b.m add radiobutton -label $mode -variable [myvar options(-mode)] -value $mode -command [mymethod set-mode $mode]
	}
	$self configure {*}$args
    }
    
    method set-mode {val} {
	if {$options(-command) ne {}} { {*}$options(-command) report -mode $val }
    }
}


