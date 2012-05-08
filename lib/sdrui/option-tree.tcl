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

package provide sdrui::option-tree 1.0.0

package require Tk
package require snit
package require sdrtk::clabelframe

snit::widgetadaptor sdrui::option-monitor {
    
    option -item {}
    option -option {}
    option -control {}

    constructor {args} {
	installhull using ttk::label
	$self configure {*}$args
	$self update
    }
    method update {} {
	$hull configure -text [$options(-control) part-cget $options(-item) $options(-option)]
    }
}

snit::widget sdrui::option-tree {
    option -container -readonly yes
    option -control -readonly yes
    
    component canvas
    component scrollbar
    component frame

    #delegate method * to treeview except {update}
    #delegate option * to treeview except {-container -control}

    variable data -array {
	items {}
	windows {}
    }
    
    constructor {args} {
	install canvas using canvas $win.c -yscrollcommand [list $win.v set]
	install scrollbar using ttk::scrollbar $win.v -orient vertical -command [list $win.c yview]
	install frame using ttk::frame $win.f
	bind $win.f <Configure> [mymethod window-configure]
	bind $win.c <Configure> [mymethod window-configure]
	grid $win.c -row 0 -column 0 -sticky nsew
	grid $win.v -row 0 -column 1 -sticky ns
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win 0 -weight 1
	$win.c create window 0 0 -window $win.f -anchor nw
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	$self update
	#bind $win.c <Button-1> [mymethod pick %W %x %y]
	#bind $win.c <Button-3> [mymethod inform %W %x %y]
    }

    proc find-parent {child items} {
	set parent {}
	foreach c [dict keys $items] {
	    if {[string first $c $child] == 0 && [string length $parent] < [string length $c]} {
		set parent $c
	    }
	}
	return $parent
    }
    proc trim-parent-prefix {parent item} {
	if {[string first $parent- $item] == 0} {
	    return [string range $item [string length $parent-] end]
	} else {
	    return $item
	}
    }
	
    method find-opts {item} { return [$options(-control) part-cget $item -opts] }

    method update {} {
	grid columnconfigure $win.f 0 -weight 1 -minsize 100
	foreach item [$options(-control) part-list] {
	    set enabled [string is true -strict [$options(-control) part-is-enabled $item]]
	    set activated [string is true -strict [$options(-control) part-is-active $item ]]
	    if { ! [dict exists $data(items) $item]} {
		set parent [find-parent $item $data(items)]
		set name [trim-parent-prefix $parent $item]
		if {$parent eq {}} {
		    set w $win.f.$name
		} else {
		    set w [dict get $data(items) $parent window].$name
		}
		dict set data(items) $item [dict create item $item type [$options(-control) part-type $item] parent $parent name $name window $w]
		grid [sdrtk::clabelframe $w -text $name] -column 0 -sticky ew
		foreach oname [$self find-opts $item] {
		    grid [ttk::label $w.l$oname -text $oname] [sdrui::option-monitor $w.m$oname -item $item -option $oname -control $options(-control)] -sticky ew
		}
		grid columnconfigure $w 0 -weight 1 -minsize 100
		grid columnconfigure $w 1 -weight 1
	    }
	    set w [dict get $data(items) $item window]
	    dict set data(items) $item enabled $enabled
	    dict set data(items) $item activated $activated
	    if {$activated} {
		$w configure -labelfg green
	    } elseif {$enabled} {
		$w configure -labelfg black
	    } else {
		$w configure -labelfg grey
	    }
	}
	set data(update-pending) 0
	$self canvas-update
    }
    method window-configure {} {
	#puts "window configure bbox [$win.c bbox all]"
	$self canvas-update
    }
    method canvas-update {} {
	#puts "canvas update bbox [$win.c bbox all]"
	if {[winfo width $win.f] != [$win.c cget -width]} {
	    $win.c configure -width [winfo width $win.f]
	}
	$win.c configure -scrollregion [$win.c bbox all]
    }
}
