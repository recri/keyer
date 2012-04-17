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

package provide sdrblk::ui-connections 1.0.0

package require Tk
package require snit
package require sdrkit::jack

snit::widget sdrblk::ui-connections {
    component sbl
    component lft
    component ctr
    component rgt
    component sbr
    component pop

    option -partof -readonly yes
    option -control -readonly yes
    option -server -readonly yes -default default

    # delegate method * to treeview except {update}
    # delegate option * to treeview except {-partof -control}

    variable data -array {
	items {}
	ports {}
	item {}
	enabled 0
	activated 0
    }
    
    method {scroll set} {who args} {
	#puts "$self scroll set $who {$args}"
	$win.$who set {*}$args
    }
    method {scroll yview} {who args} {
	#puts "$self scroll yview {$args}"
	$win.$who yview {*}$args
    }

    constructor {args} {
	install sbl using ttk::scrollbar $win.sbl -orient vertical -command [mymethod scroll yview lft]
	install lft using ttk::treeview $win.lft -show tree -yscrollcommand [mymethod scroll set sbl]
	install ctr using canvas $win.ctr -width 100
	install rgt using ttk::treeview $win.rgt -show tree -yscrollcommand [mymethod scroll set sbr]
	install sbr using ttk::scrollbar $win.sbr -orient vertical -command [mymethod scroll yview rgt]
	install pop using menu $win.pop -tearoff no
	grid [ttk::label $win.ll -text source] -row 0 -column 0 -columnspan 2
	grid [ttk::label $win.lc -text connect] -row 0 -column 2
	grid [ttk::label $win.lr -text sink] -row 0 -column 3 -columnspan 2
	grid $win.sbl -row 1 -column 0 -sticky ns
	grid $win.lft -row 1 -column 1 -sticky nsew
	grid $win.ctr -row 1 -column 2 -sticky nsew
	grid $win.rgt -row 1 -column 3 -sticky nsew
	grid $win.sbr -row 1 -column 4 -sticky ns
	foreach c {1 2 3} { grid columnconfigure $win $c -weight 1 }
	grid rowconfigure $win 1 -weight 1
	$self configure {*}$args
	set options(-control) [$options(-partof) cget -control]
	set data(items) [dict create]
	$self update
	#$pop add command -label dummy -state disabled
	#$pop entryconfigure 0 -disabledforeground [$pop entrycget 0 -foreground]
	#$pop add separator
	$pop add checkbutton -label enable -variable [myvar data(enabled)] -command [mymethod pop-enable]
	$pop add checkbutton -label activate -variable [myvar data(activated)] -command [mymethod pop-activate]
	$pop add separator
	$pop add command -label configuration -command [mymethod pop-configuration]
	$pop add command -label controls -command [mymethod pop-controls]
	foreach w {lft ctr rgt} {
	    bind $win.$w <Button-3> [mymethod pop-up %W %x %y]
	    #bind $win.$w <Button-3> [mymethod inform $w %W %x %y]
	}
    }

    proc find-parent {child items} {
	set parent {}
	foreach c [dict keys $items] {
	    if {[string first $c $child] == 0 &&
		[string length $parent] < [string length $c]} {
		set parent $c
	    }
	}
	return $parent
    }

    proc find-ports {client ports} {
	set cports {}
	foreach name [dict keys $ports] {
	    if {[string first ${client}: $name] == 0} {
		lappend cports [list $name [dict get $ports $name]]
	    }
	}
	return $cports
    }
	
    method update {} {
	set data(ports) [sdrkit::jack -server $options(-server) list-ports]
	foreach label [$options(-control) list] {
	    set enabled [string is true -strict [$options(-control) ccget $label -enable]]
	    set activated [string is true -strict [$options(-control) ccget $label -activate]]
	    if { ! [dict exists $data(items) $label]} {
		set parent [find-parent $label $data(items)]
		dict set data(items) $label [dict create type [$options(-control) ccget $label -type]]
		foreach w {lft rgt} {
		    $win.$w insert $parent end -id $label -text $label -tag $label
		}
	    }
	    dict set data(items) $label enabled $enabled
	    dict set data(items) $label activated $activated
	    if {$activated} {
		foreach w {lft rgt} {
		    $win.$w tag configure $label -foreground black -background white
		}
	    } elseif {$enabled} {
		foreach w {lft rgt} {
		    $win.$w tag configure $label -foreground black -background white
		}
	    } else {
		foreach w {lft rgt} {
		    $win.$w tag configure $label -foreground grey -background white
		}
	    }
	    foreach port [find-ports $label $data(ports)] {
		# puts "$label: found $port"
	    }
	}
    }

    method pop-enable {} {
	if {$data(enabled)} {
	    $options(-control) enable $data(item)
	} else {
	    $options(-control) disable $data(item)
	}
	after 10 [mymethod update]
    }
    method pop-activate {} {
	if {$data(activated)} {
	    $options(-control) activate $data(item)
	} else {
	    $options(-control) deactivate $data(item)
	}
	after 10 [mymethod update]
    }
    method pop-configuration {} {
	if {[$options(-control) exists $data(item)]} {
	    puts "-- $data(item) -- configuration"
	    foreach c [$options(-control) cconfigure $data(item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }
    method pop-controls {} {
	if {[$options(-control) exists $data(item)]} {
	    puts "-- $data(item) -- controls"
	    foreach c [$options(-control) controls $data(item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }

    method pop-up {w x y} {
	set data(item) [$w identify item $x $y]
	set data(enabled) [dict get $data(items) $data(item) enabled]
	set data(activated) [dict get $data(items) $data(item) activated]
	switch [dict get $data(items) $data(item) type] {
	    sequence {
		$pop entryconfigure 0 -state disabled
		$pop entryconfigure 1 -state normal
	    }
	    jack {
		$pop entryconfigure 0 -state normal
		$pop entryconfigure 1 -state disabled
	    }
	    default {
		$pop entryconfigure 0 -state disabled
		$pop entryconfigure 1 -state disabled
	    }
	}
	#$pop entryconfigure 0 -label $data(item)
	tk_popup $pop {*}[winfo pointerxy $w]
    }

    method inform {who w x y} {
	set item [$w identify item $x $y]
    }
}
