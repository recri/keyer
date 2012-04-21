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

    
snit::widgetadaptor sdrui::iambic {
    component iambic
    component wwpm
    component wpm
    component wdah
    component dah
    component wspace
    component space

    option -iambic -default ad5dz -type {snit::enum -values {ad5dz dttsp nd7pa}}
    option -wpm -default 15
    option -dah -default 3
    option -space -default 1
    option -command {}
    option -controls {-iambic -wpm -dah -space}

    delegate option -label to hull as -text
    delegate option -labelanchor to hull

    constructor {args} {
	installhull using ttk::labelframe
	install iambic using ttk::menubutton $win.m -textvar [myvar options(-iambic)] -menu $win.m.m
	menu $win.m.m -tearoff no
	foreach i {ad5dz dttsp nd7pa} {
	    $win.m.m add radiobutton -label $i -value $i -variable [myvar options(-iambic)] -command [mymethod set-iambic]
	}
	install wwpm using ttk::labelframe $win.w -text WPM
	install wpm using ttk::spinbox $win.w.s -from 5 -to 60 -increment 1 -textvariable [myvar options(-wpm)] -command [mymethod set-wpm]
	install wdah using ttk::labelframe $win.d -text Dah
	install dah using ttk::spinbox $win.d.s -from 2.5 -to 3.5 -increment 0.1 -textvariable [myvar options(-dah)] -command [mymethod set-dah]
	install wspace using ttk::labelframe $win.s -text Space
	install space using ttk::spinbox $win.s.s -from 0.8 -to 1.2 -increment 0.01 -textvariable [myvar options(-space)] -command [mymethod set-space]
	pack $win.m -fill x -expand true -side top 
	pack $win.w.s -fill x -expand true
	pack $win.w -fill x -expand true -side top
	pack $win.d.s -fill x -expand true
	pack $win.d -fill x -expand true -side top
	pack $win.s.s -fill x -expand true
	pack $win.s -fill x -expand true -side top
	foreach {opt val} { -label {Debounce} -labelanchor n } {
	    if {[lsearch $args $opt] < 0} { lappend args $opt $val }
	}
	$self configure {*}$args
    }

    method set-iambic {} { if {$options(-command) ne {}} { {*}$options(-command) report -iambic $options(-iambic) } }
    method set-wpm {} { if {$options(-command) ne {}} { {*}$options(-command) report -wpm $options(-wpm) } }
    method set-dah {} { if {$options(-command) ne {}} { {*}$options(-command) report -dah $options(-dah) } }
    method set-space {} { if {$options(-command) ne {}} { {*}$options(-command) report -space $options(-space) } }
}


