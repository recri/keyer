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

package provide sdrui::tree 1.0.0

package require Tk
package require snit

snit::widget sdrui::tree {
    option -container -readonly yes
    option -control -readonly yes
    
    component treeview
    component scrollbar

    delegate method * to treeview except {update}
    delegate option * to treeview except {-container -control}

    variable columns {value}
    variable items -array {}
    
    constructor {args} {
	install treeview using ttk::treeview $win.t -show tree -columns $columns -displaycolumns $columns -yscrollcommand [list $win.v set]
	install scrollbar using ttk::scrollbar $win.v -orient vertical -command [list $win.t yview]
	$win.t heading #0 -text module
	$win.t column #0 -width [expr {30*8}] -stretch no -anchor w
	pack $win.t -side left -fill both -expand true
	pack $win.v -side left -fill y
	foreach c $columns {
	    $win.t heading $c -text $c
	    switch $c {
		type { $win.t column $c -width [expr {7*8}] -stretch no -anchor center }
		enabled { $win.t column $c -width [expr {7*8}] -stretch no -anchor center }
		inport -
		outport { $win.t column $c -width [expr {30*8}] }
		control { $win.t column $c -width [expr {10*8}] -anchor e}
		value { $win.t column $c -width [expr {10*8}] -anchor e }
		default { $win.t column $c -width [expr {10*8}] -anchor center }
	    }
	}
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	$self update
	bind $win.t <Button-1> [mymethod pick %W %x %y]
	bind $win.t <Button-3> [mymethod inform %W %x %y]
    }

    proc find-parent {candidates child} {
	set parent {}
	foreach c $candidates {
	    if {[string first $c $child] == 0 &&
		[string length $parent] < [string length $c]} {
		set parent $c
	    }
	}
	return $parent
    }

    method values {item} {
	# puts "values for $options(-control) ccget $item -type"
	set type [$options(-control) part-type $item]
	set enabled [$options(-control) part-is-enabled $item]
	set activated [$options(-control) part-is-active $item]
	#set inport [$options(-control) ccget $item -inport]
	#set outport [$options(-control) ccget $item -outport]
	#return [list $type $enabled $inport $outport {} {}]
	if {$enabled && $activated} {
	    return [list {on}]
	} elseif {$enabled} {
	    return [list {ready}]
	} else {
	    return [list {off}]
	}
    }
    
    method control-values {item opt} {
	#return [list {} {} {} {} $opt [$options(-control) controlget $item $opt]]
	return [list [$options(-control) part-cget $item $opt]]
    }

    method update {} {
	catch {$hull delete all}
	array set items {}
	set labels {}
	foreach label [$options(-control) part-list] {
	    set enabled [$options(-control) part-is-enabled $label]
	    set activated [$options(-control) part-is-active $label]
	    set values [$self values $label]
	    if { ! [info exists items($label)]} {
		$win.t insert [find-parent [array names items] $label] end -id $label -text $label -values $values -tag $label
		set items($label) [$options(-control) part-type $label]
	    } else {
		$win.t item $label -values $values -tag $label
	    }
	    if {$activated} {
		$win.t tag configure $label -foreground black -background white
	    } elseif {$enabled} {
		$win.t tag configure $label -foreground black -background white
	    } else {
		$win.t tag configure $label -foreground grey -background white
	    }
	    foreach option [$options(-control) opt-filter [list $label *]] {
		set optname [lindex $option 1]
		switch -- $optname {
		    -opt-connect-to -
		    -opt-connect-from -
		    -verbose -
		    -client -
		    -server { }
		    default {
			set optlabel "$label:$optname"
			set values [$self control-values $label $optname]
			if { ! [info exists items($optlabel)]} {
			    $win.t insert $label end -id $optlabel -text $optname -values $values -tag $label
			    set items($optlabel) control
			} else {
			    $win.t item $optlabel -values $values
			}
		    }
		}
	    }
	}
    }

    method pick {w x y} {
	if {[$w identify region $x $y] eq {cell}} {
	    set item [$w identify item $x $y]
	    set type $items($item)
	    set col [lindex $columns [expr {[string range [$w identify column $x $y] 1 end]-1}]]
	    switch $type {
		sequence {
		    if {$col eq {value}} {
			if {[$options(-control) part-is-active $item]} {
			    $options(-control) part-deactivate $item
			} else {
			    $options(-control) part-activate $item
			}
			$self update
		    }
		}
		jack {
		    if {$col eq {value}} {
			if {[$options(-control) part-is-enabled $item]} {
			    $options(-control) part-disable $item
			} else { 
			    $options(-control) part-enable $item
			}
			$self update
		    }
		}
		meter - spectrum -
		input - output - alternate {
		}
		control {
		    if {$col eq {value}} {
			puts "control $item selected"
		    }
		}
		default {
		    puts "ui-tree::pick type = $type?"
		}
	    }
	}
    }

    method inform {w x y} {
	set item [$w identify item $x $y]
	puts "$item at $x $y"
	if {[$options(-control) part-exists $item]} {
	    puts "$item exists"
	    foreach c [$options(-control) part-configure $item] {
		puts "$item: [lindex $c 0] {[lindex $c end]}"
	    }
	}
    }
}
