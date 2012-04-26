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
## iambic - keyer iambic control
##
package provide sdrui::iambic 1.0.0

package require Tk
package require snit

package require sdrctl::types
    
snit::widgetadaptor sdrui::iambic {
    component iambic

    option -iambic -default ad5dz -type sdrctl::iambic

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install iambic using ttk::menubutton $win.m -textvar [myvar options(-iambic)] -menu $win.m.m
	menu $win.m.m -tearoff no
	foreach i [sdrctl::iambic cget -values] {
	    $win.m.m add radiobutton -label $i -value $i -variable [myvar options(-iambic)] -command [mymethod set-iambic]
	}
	pack $win.m -fill x -expand true -side top 
	foreach {opt val} { -label {Iambic} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-iambic} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }

    method set-iambic {} { if {$options(-command) ne {}} { {*}$options(-command) report -iambic $options(-iambic) } }
}

snit::widgetadaptor sdrui::iambic-wpm {
    component wpm

    option -wpm -default 15
    option -command {}
    option -controls {-wpm}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install wpm using ttk::spinbox $win.w -from 5 -to 60 -increment 1 -width 4 -textvariable [myvar options(-wpm)] -command [mymethod set-wpm]
	pack $win.w -fill x -expand true -side top 
	foreach {opt val} { -label {WPM} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-wpm {} { if {$options(-command) ne {}} { {*}$options(-command) report -wpm $options(-wpm) } }
}

snit::widgetadaptor sdrui::iambic-dah {
    component dah

    option -dah -default 3
    option -command {}
    option -controls {-dah}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install dah using ttk::spinbox $win.d -from 2.5 -to 3.5 -increment 0.1 -width 4 -textvariable [myvar options(-dah)] -command [mymethod set-dah]
	pack $win.d -fill x -expand true
	foreach {opt val} { -label {Dah} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-dah {} { if {$options(-command) ne {}} { {*}$options(-command) report -dah $options(-dah) } }
}

snit::widgetadaptor sdrui::iambic-space {
    component space

    option -space -default 1
    option -command {}
    option -controls {-space}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install space using ttk::spinbox $win.d -from 0.7 -to 1.3 -increment 0.1 -width 4 -textvariable [myvar options(-space)] -command [mymethod set-space]
	pack $win.d -fill x -expand true
	foreach {opt val} { -label {Space} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-space {} { if {$options(-command) ne {}} { {*}$options(-command) report -space $options(-space) } }
}
