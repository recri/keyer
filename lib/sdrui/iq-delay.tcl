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
## iq-swap - I/Q channel delay control
##
package provide sdrui::iq-delay 1.0.0

package require Tk
package require snit

package require sdrtype::types
    
snit::widgetadaptor sdrui::iq-delay {
    component button

    option -delay -default 0 -type sdrtype::iq-delay

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install button using ttk::menubutton $win.delay -textvar [myvar options(-delay)] -menu $win.delay.m
	install menu using menu $win.delay.m -tearoff no
	foreach val [sdrtype::iq-delay cget -values] {
	    $win.delay.m add radiobutton -label $val -value $val -variable [myvar options(-delay)] -command [mymethod set-delay]
	}
	pack $win.delay -fill x -expand true
	foreach {opt val} { -label {IQ delay} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-delay} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }

    method set-delay {} { if {$options(-command) ne {}} { {*}$options(-command) report -delay $options(-delay) } }
}


