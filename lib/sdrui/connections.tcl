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

namespace eval sdrui {}
namespace eval sdrui::connections {}

#
# a scrolling treeview with scrollbar to left or right
#
snit::widgetadaptor sdrui::connections::treeview {
    component treeview
    component scrollbar

    option -scrollbar -default right -readonly true -type {snit::enum -values {left right}}
    option -container {}
    option -width -configuremethod Width

    delegate option -text to hull
    delegate option -labelanchor to hull

    delegate method * to treeview
    delegate option * to treeview

    constructor {args} {
	installhull using ttk::labelframe
	install treeview using ttk::treeview $win.t -yscrollcommand [mymethod Scroll set $win.v]
	install scrollbar using ttk::scrollbar $win.v -orient vertical -command [mymethod Scroll yview $win.t]
	$self configure {*}$args
	if {$options(-scrollbar) eq {left}} {
	    pack $win.t -side right -fill both -expand true
	    pack $win.v -side right -fill y
	} else {    
	    pack $win.t -side left -fill both -expand true
	    pack $win.v -side left -fill y
	}
	bind $win.t <Button-3> [list $options(-container) pop-up %W %x %y]
	bind $win.t <<TreeviewOpen>> [list $options(-container) defer-update-canvas]
	bind $win.t <<TreeviewClose>> [list $options(-container) defer-update-canvas]
	bind $win.t <<TreeviewSelect>> [list $options(-container) item-select %W]
    }

    method {Width -width} {val} {
	$treeview column #0 -width $val
    }

    method {Scroll set} {w args} {
	$w set {*}$args
	$options(-container) defer-update-canvas
    }

    method {Scroll yview} {w args} {
	$w yview {*}$args
	$options(-container) defer-update-canvas
    }
}
 
##
## a canvas in a labelled frame
##
snit::widgetadaptor sdrui::connections::labelcanvas {
    component canvas
    
    option -container {}

    delegate option -text to hull
    delegate option -labelanchor to hull
    
    delegate option * to canvas
    delegate method * to canvas

    constructor {args} {
	installhull using ttk::labelframe
	install canvas using canvas $win.c
	pack $canvas -fill both -expand true
	$self configure {*}$args
	bind $canvas <Configure> [list $options(-container) defer-update-canvas]
    }
}

snit::widget sdrui::connections {
    component pane
    component lft
    component ctr
    component rgt
    component pop

    option -container -readonly yes
    option -control -readonly yes
    option -server -readonly yes -default default
    option -defer-ms -default 100
    option -show -default port -type {snit::enum -values {opt port active}}
    option -filter -default 0 -type snit::boolean

    # delegate method * to treeview except {update}
    # delegate option * to treeview except {-container -control}

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
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]

	install pane using ttk::panedwindow $win.pane -orient horizontal
	install lft using connections::treeview $win.lft -scrollbar left -width 100 -show tree -container $self
	install ctr using connections::labelcanvas $win.ctr -width 100 -container $self
	install rgt using connections::treeview $win.rgt -scrollbar right -width 100 -show tree -container $self
	grid $pane -row 0 -column 0 -sticky nsew
	$pane add $lft -weight 1
	$pane add $ctr -weight 2
	$pane add $rgt -weight 1
	$lft configure -text source -labelanchor n
	$ctr configure -text connect -labelanchor n
	$rgt configure -text sink -labelanchor n
	grid [ttk::checkbutton $win.ctl] -row 1 -column 0
	grid [ttk::checkbutton $win.filter -text {filter by selection} -variable [myvar options(-filter)] -command [mymethod defer-update-canvas]] -in $win.ctl -row 0 -column 0
	grid [ttk::menubutton $win.show -textvar [myvar options(-show)] -menu $win.show.m] -in $win.ctl -row 0 -column 1
	menu $win.show.m -tearoff no
	foreach v {opt port active} {
	    $win.show.m add radiobutton -label $v -variable [myvar options(-show)] -value $v -command [mymethod do-over]
	}
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win 0 -weight 1

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

	set data(items) [dict create]
	$self update
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

    method find-ports {item} { return [$options(-control) part-cget $item -ports] }
    method find-port-connections-from {item} { return [$options(-control) port-connections-from {*}[split $item :]] }
    method find-port-connections-to {item} { return [$options(-control) port-connections-to {*}[split $item :]] }

    method find-active {item ports} {
	set active {}
	foreach key [dict keys $ports $item:*] {
	    lappend active $key [dict get $ports $key]
	}
	return $active
    }
	
    method find-opts {item} { return [$options(-control) part-cget $item -opts] }
    method find-opt-connections {item} { return [$options(-control) opt-connections-from {*}[split $item :]] }

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

    method do-over {} {
	foreach item [dict keys $data(items)] {
	    switch [dict get $data(items) $item type] {
		ctl - ui - hw - dsp - jack {}
		port - audio - midi - opt {
		    if {[$lft exists $item]} { $lft delete $item }
		    if {[$rgt exists $item]} { $rgt delete $item }
		    dict unset data(items) $item
		}
		default {
		    puts "unknown type: [dict get $data(items) $item type]"
		}
	    }
	}
	$self update
    }

    method update {} {
	# insert system playback, capture, and midi ports
	set ports [sdrkit::jack -server $options(-server) list-ports]
	foreach item [$options(-control) part-list] {
	    set enabled [string is true -strict [$options(-control) part-is-enabled $item]]
	    set activated [string is true -strict [$options(-control) part-is-active $item ]]
	    if { ! [dict exists $data(items) $item]} {
		set parent [find-parent $item $data(items)]
		set name [trim-parent-prefix $parent $item]
		dict set data(items) $item [dict create item $item type [$options(-control) part-type $item] parent $parent name $name]
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
	    switch $options(-show) {
		port {
		    foreach pname [$self find-ports $item] {
			set pitem $item:$pname
			if { ! [dict exists $data(items) $pitem]} {
			    set pdict [dict create type port item $item parent $item name $pname]
			    dict set data(items) $pitem $pdict
			    if {[llength [$self find-port-connections-from $pitem]] || [string match *capture* $pname]} {
				$win.lft insert $item end -id $pitem -text $pname -tags [list $item $pitem]
			    }
			    if {[llength [$self find-port-connections-to $pitem]] || [string match *playback* $pname]} {
				$win.rgt insert $item end -id $pitem -text $pname -tags [list $item $pitem]
			    }
			}
		    }
		}
		active {
		    foreach {pitem pdict} [$self find-active $item $ports] {
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
		opt {
		    foreach oname [$self find-opts $item] {
			set oitem $item:$oname
			dict set data(items) $oitem [dict create type opt item $item parent $item name $oname]
			$win.lft insert $item end -id $oitem -text $oname -tags [list $item $oitem]
			$win.rgt insert $item end -id $oitem -text $oname -tags [list $item $oitem]
		    }
		}
	    }
	}
	set data(connections) {}
	foreach item [dict keys $data(items)] {
	    set idict [dict get $data(items) $item]
	    switch [dict get $idict type] {
		audio - midi {
		    if {[dict get $idict direction] eq {output}} {
			# use the latest list-ports, not the first one
			foreach o [dict get $ports $item connections] {
			    lappend data(connections) $item $o
			}
		    }
		}
		port {
		    foreach dest [$self find-port-connections-from $item] {
			lappend data(connections) $item [join $dest :]
		    }
		}
		opt {
		    foreach dest [$self find-opt-connections $item] {
			# puts "adding connection $item -> $dest"
			lappend data(connections) $item [join $dest :]
		    }
		}
	    }
	}
	$self update-canvas
	set data(update-pending) 0
    }
    
    method find-selection {lor} {
	set sel [$win.$lor selection]
	# expand to recursively include children of selected
	foreach item [dict keys $data(items)] {
	    if {[dict get $data(items) $item parent] in $sel} {
		lappend sel $item
	    }
	}
	return $sel
    }

    method defer-update-canvas {} {
	if {$data(update-canvas-pending) == 0} {
	    set data(update-canvas-pending) 1
	    after $options(-defer-ms) [mymethod update-canvas]
	}
    }
    
    method update-canvas {} {
	# need to figure out if the connection line terminates above or below
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
	if {$options(-filter)} {
	    set slft [$self find-selection lft]
	    set srgt [$self find-selection rgt]
	}
	foreach {i o} $data(connections) {
	    # puts "preparing to draw $i ([dict exists $data(items) $i]) -> $o ([dict exists $data(items) $o])"
	    if {$options(-filter) && [lsearch $slft $i] < 0} continue
	    if {$options(-filter) && [lsearch $srgt $o] < 0} continue
	    if { ! [dict exists $data(items) $i] || ! [dict exists $data(items) $o]} continue
	    set ly [dict get $data(items) $i lft-y]
	    set ry [dict get $data(items) $o rgt-y]
	    if {$ly eq {} || $ry eq {}} continue
	    $win.ctr create line $x0 $ly $x1 $ly $x2 $ry $x3 $ry -smooth true -width 2

	}
	set data(update-canvas-pending) 0
    }
    
    ##
    ## popup menu on right button
    ##
    method pop-enable {} {
	if {$data(pop-enabled)} {
	    $options(-control) part-enable $data(pop-item)
	} else {
	    $options(-control) part-disable $data(pop-item)
	}
	$self defer-update
    }
    
    method pop-activate {} {
	if {$data(pop-activated)} {
	    $options(-control) part-activate-tree $data(pop-item)
	} else {
	    $options(-control) part-deactivate-tree $data(pop-item)
	}
	$self defer-update
    }
    
    method pop-configuration {} {
	if {[$options(-control) part-exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- configuration"
	    foreach c [$options(-control) part-configure $data(pop-item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }
    
    method pop-controls {} {
	if {[$options(-control) part-exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- opts"
	    foreach c [$options(-control) opt-filter [list $data(pop-item) *]] {
		set opt [lindex $c 1]
		puts "-- $opt {[$options(-control) part-cget $data(pop-item) $opt]}"
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
	    dsp {
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
	if {$options(-filter)} { $self defer-update-canvas }
    }
}
