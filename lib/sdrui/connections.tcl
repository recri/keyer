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

package provide sdrui::connections 1.0.0

#
# connections draws a collapsable tree for the dsp components
# in the radio and shows which components are connected
# it also allows the configuration and controls of each component
# to be printed to standard output
#
package require Tk
package require snit
package require sdrkit::jack

snit::widget sdrui::connections {
    component sbl
    component lft
    component ctr
    component rgt
    component sbr
    component pop

    option -partof -readonly yes
    option -control -readonly yes
    option -server -readonly yes -default default
    option -defer-ms -default 100

    # delegate method * to treeview except {update}
    # delegate option * to treeview except {-partof -control}

    variable data -array {
	items {}
	update-pending 0
	update-canvas-pending 0
	pop-item {}
	pop-enabled 0
	pop-activated 0
	pop-type {}
    }
    
    constructor {args} {
	install sbl using ttk::scrollbar $win.sbl -orient vertical -command [mymethod scroll yview lft]
	install lft using ttk::treeview $win.lft -show tree -yscrollcommand [mymethod scroll set sbl] -selectmode browse
	install ctr using canvas $win.ctr -width 100
	install rgt using ttk::treeview $win.rgt -show tree -yscrollcommand [mymethod scroll set sbr] -selectmode browse
	install sbr using ttk::scrollbar $win.sbr -orient vertical -command [mymethod scroll yview rgt]

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

	install pop using menu $win.pop -tearoff no
	$pop add checkbutton -label enable -variable [myvar data(pop-enabled)] -command [mymethod pop-enable]
	$pop add checkbutton -label activate -variable [myvar data(pop-activated)] -command [mymethod pop-activate]
	#$pop add separator
	#$pop add command -label open -command [mymethod pop-open]
	#$pop add command -label collapse -command [mymethod pop-collapse]
	$pop add separator
	$pop add command -label {open all} -command [mymethod pop-open-all]
	$pop add command -label {collapse all} -command [mymethod pop-collapse-all]
	$pop add separator
	$pop add command -label configuration -command [mymethod pop-configuration]
	$pop add command -label controls -command [mymethod pop-controls]

	foreach w {lft ctr rgt} {
	    bind $win.$w <Button-3> [mymethod pop-up %W %x %y]
	    bind $win.$w <<TreeviewOpen>> [mymethod defer-update-canvas]
	    bind $win.$w <<TreeviewClose>> [mymethod defer-update-canvas]
	    bind $win.$w <<TreeviewSelect>> [mymethod item-select $win.$w]
	}

	$self update

    }

    method {scroll set} {who args} {
	#puts "$self scroll set $who {$args}"
	$win.$who set {*}$args
	$self defer-update-canvas
    }

    method {scroll yview} {who args} {
	#puts "$self scroll yview {$args}"
	$win.$who yview {*}$args
	$self defer-update-canvas
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

    proc find-ports {item ports} {
	set cports {}
	foreach port [dict keys $ports] {
	    if {[string first ${item}: $port] == 0} {
		lappend cports [list $port [dict get $ports $port]]
	    }
	}
	return $cports
    }
	
    proc trim-parent-prefix {parent item} {
	if {[string first $parent- $item] == 0} {
	    return [string range $item [string length $parent-] end]
	} else {
	    return $item
	}
    }
	
    method defer-update {} {
	if {$data(update-pending) == 0} {
	    set data(update-pending) 1
	    after $options(-defer-ms) [mymethod update]
	}
    }

    method update {} {
	# insert system playback, capture, and midi ports
	set ports [sdrkit::jack -server $options(-server) list-ports]
	foreach item [$options(-control) list] {
	    set enabled [string is true -strict [$options(-control) ccget $item -enable]]
	    set activated [string is true -strict [$options(-control) ccget $item -activate]]
	    if { ! [dict exists $data(items) $item]} {
		set parent [find-parent $item $data(items)]
		set name [trim-parent-prefix $parent $item]
		dict set data(items) $item [dict create item $item type [$options(-control) ccget $item -type] parent $parent name $name]
		foreach w {lft rgt} {
		    $win.$w insert $parent end -id $item -text $name -tag $item
		}
	    }
	    dict set data(items) $item enabled $enabled
	    dict set data(items) $item activated $activated
	    #puts "$item enabled=$enabled [$options(-control) ccget $item -enable]"
	    #puts "$item activated=$activated [$options(-control) ccget $item -activate]"
	    if {$activated} {
		foreach w {lft rgt} {
		    $win.$w tag configure $item -foreground black -background white
		}
	    } elseif {$enabled} {
		foreach w {lft rgt} {
		    $win.$w tag configure $item -foreground black -background white
		}
	    } else {
		foreach w {lft rgt} {
		    $win.$w tag configure $item -foreground grey -background white
		}
	    }
	    foreach port [find-ports $item $ports] {
		lassign $port pitem pdict
		if { ! [dict exists $data(items) $pitem]} {
		    set pname [lindex [split $pitem :] 1]
		    dict set pdict item $item
		    dict set pdict parent $item
		    dict set pdict name $pname
		    dict set data(items) $pitem $pdict
		    switch [dict get $pdict direction] {
			output { $win.lft insert $item end -id $pitem -text $pname -tags [list $item $pitem] }
			input { $win.rgt insert $item end -id $pitem -text $pname -tags [list $item $pitem] }
		    }
		}
	    }
	}
	set data(connections) {}
	foreach item [dict keys $data(items)] {
	    set idict [dict get $data(items) $item]
	    if {[dict get $idict type] in {audio midi}} {
		if {[dict get $idict direction] eq {output}} {
		    # use the latest list-ports, not the first one
		    foreach o [dict get $ports $item connections] {
			lappend data(connections) $item $o
		    }
		}
	    }
	}
	$self update-canvas
	set data(update-pending) 0
    }

    method defer-update-canvas {} {
	if {$data(update-canvas-pending) == 0} {
	    set data(update-canvas-pending) 1
	    after $options(-defer-ms) [mymethod update-canvas]
	}
    }

    method update-canvas {} {
	foreach item [dict keys $data(items)] {
	    foreach w {lft rgt} {
		# initialize y coordinate
		dict set data(items) $item $w-y {}
		# find y coordinate
		if {[$win.$w exists $item]} {
		    set bbox [$win.$w bbox $item] 
		    if {$bbox ne {}} {
			lassign $bbox x y wd ht
			dict set data(items) $item $w-y [expr {$y+$ht/2.0}]
		    }
		}
		# find parental y coordinate if necessary
		if {[dict get $data(items) $item $w-y] eq {}} {
		    for {set p [dict get $data(items) $item parent]} {$p ne {}} {set p [dict get $data(items) $p parent]} {
			set y [dict get $data(items) $p $w-y]
			if {$y ne {}} {
			    dict set data(items) $item $w-y $y
			    break
			}
		    }
		}
	    }
	}
	# draw the lines
	$win.ctr delete all
	set wd [winfo width $win.ctr]
	set x0 0
	set x1 [expr {$wd/8.0}]
	set x2 [expr {$wd-1-$wd/8.0}]
	set x3 [expr {$wd-1}]
	foreach {i o} $data(connections) {
	    if {[dict exists $data(items) $i] && [dict exists $data(items) $o]} {
		set ly [dict get $data(items) $i lft-y]
		set ry [dict get $data(items) $o rgt-y]
		if {$ly ne {} && $ry ne {}} {
			    $win.ctr create line $x0 $ly $x1 $ly $x2 $ry $x3 $ry -smooth true -width 2
		}
	    }
	}
	set data(update-canvas-pending) 0
    }

    ##
    ## popup menu on right button
    ##
    method pop-enable {} {
	if {$data(pop-enabled)} {
	    $options(-control) enable $data(pop-item)
	} else {
	    $options(-control) disable $data(pop-item)
	}
	$self defer-update
    }

    method pop-activate {} {
	if {$data(pop-activated)} {
	    $options(-control) activate $data(pop-item)
	} else {
	    $options(-control) deactivate $data(pop-item)
	}
	$self defer-update
    }

    method pop-configuration {} {
	if {[$options(-control) exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- configuration"
	    foreach c [$options(-control) cconfigure $data(pop-item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }

    method pop-controls {} {
	if {[$options(-control) exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- controls"
	    foreach c [$options(-control) controls $data(pop-item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }

    proc item-open {w item true recurse} {
	$w item $item -open $true
	if {$recurse} {
	    foreach child [$w children $item] {
		item-open $w $child $true $recurse
	    }
	}
    }

    method pop-open {} { item-open $data(pop-window) $data(pop-item) true false }
    method pop-collapse {} { item-open $data(pop-window) $data(pop-item) false false }
    method pop-open-all {} { item-open $data(pop-window) $data(pop-item) true true }
    method pop-collapse-all {} { item-open $data(pop-window) $data(pop-item) false true }
    
    method pop-up {w x y} {
	set data(pop-window) $w
	set data(pop-item) [$w identify item $x $y]
	set data(pop-enabled) [dict get $data(items) $data(pop-item) enabled]
	set data(pop-activated) [dict get $data(items) $data(pop-item) activated]
	set data(pop-type) [dict get $data(items) $data(pop-item) type]
	set data(pop-parent) [dict get $data(items) $data(pop-item) parent]
	switch $data(pop-type) {
	    sequence {
		$pop entryconfigure 0 -state disabled
		if {$data(pop-parent) eq {}} {
		    $pop entryconfigure 1 -state normal
		} else {
		    $pop entryconfigure 1 -state disabled
		}
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
	tk_popup $pop {*}[winfo pointerxy $w]
    }

    method item-select {w} {
	# puts "item-select $w -- [$w selection]"
    }
}
