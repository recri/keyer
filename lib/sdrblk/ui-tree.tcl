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

package provide sdrblk::ui-tree 1.0.0

package require Tk
package require snit

::snit::widget sdrblk::ui-tree {
    option -partof -readonly yes
    option -control -readonly yes
    
    component treeview
    component scrollbar

    delegate method * to treeview except {update}
    delegate option * to treeview except {-partof -control}

    variable columns {type works enabled in out control value}
    variable items -array {}
    
    constructor {args} {
	puts "radio-ui-tree constructor $args"
	install treeview using ttk::treeview $win.t -columns $columns -displaycolumns $columns -yscrollcommand [list $win.v set]
	install scrollbar using ttk::scrollbar $win.v -orient vertical -command [list $win.t yview]
	$win.t heading #0 -text module
	$win.t column #0 -width [expr {30*8}] -stretch no -anchor w
	pack $win.t -side left -fill both -expand true
	pack $win.v -side left -fill y
	foreach c $columns {
	    $win.t heading $c -text $c
	    switch $c {
		type { $win.t column $c -width [expr {7*8}] -stretch no -anchor center }
		works { $win.t column $c -width [expr {6*8}] -stretch no -anchor center }
		enabled { $win.t column $c -width [expr {7*8}] -stretch no -anchor center }
		inport -
		outport { $win.t column $c -width [expr {30*8}] }
		control { $win.t column $c -width [expr {10*8}] -anchor e}
		value { $win.t column $c -width [expr {10*8}] -anchor e }
		default { $win.t column $c -width [expr {10*8}] -anchor center }
	    }
	}
	$self configure {*}$args
	set options(-control) [$options(-partof) cget -control]
	$self update
	bind $win.t <Button-1> [mymethod pick %W %x %y]
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
	set type [$options(-control) ccget $item -type]
	set implemented [$options(-control) ccget $item -implemented]
	set enabled [$options(-control) ccget $item -enable]
	set inport [$options(-control) ccget $item -inport]
	set outport [$options(-control) ccget $item -outport]
	return [list $type $implemented $enabled $inport $outport {} {}]
    }
    
    method control-values {item opt} {
	return [list {} {} {} {} {} $opt [$options(-control) controlget $item $opt]]
    }

    method update {} {
	catch {$hull delete all}
	array set items {}
	set labels {}
	foreach label [$options(-control) list] {
	    set enabled [$options(-control) ccget $label -enable]
	    set values [$self values $label]
	    if { ! [info exists items($label)]} {
		$win.t insert [find-parent [array names items] $label] end -id $label -text $label -values $values
		set items($label) module
	    } else {
		$win.t item $label -values $values
	    }
	    if {$enabled} {
		foreach option [$options(-control) controls $label] {
		    set optname [lindex $option 0]
		    switch -- $optname {
			-verbose -
			-client -
			-server { }
			default {
			    set optlabel $label-$optname
			    set values [$self control-values $label $optname]
			    if { ! [info exists items($optlabel)]} {
				$win.t insert $label end -id $optlabel -values $values
				set items($optlabel) option
			    } else {
				$win.t item $optlabel -values
			    }
			}
		    }
		}
	    } else {
		# if there are options listed, grey them out
	    }
	}
    }

    method pick {w x y} {
	if {[$w identify region $x $y] eq {cell}} {
	    set item [$w identify item $x $y]
	    set type $items($item)
	    set col [lindex $columns [expr {[string range [$w identify column $x $y] 1 end]-1}]]
	    if {$type eq {module}} {
		if {$col eq {enabled}} {
		    if {[$options(-control) ccget $item -enable]} {
			$options(-control) disable $item
		    } else { 
			$options(-control) enable $item
		    }
		    $self update
		}
	    }	
	    puts "pick $item $col"
	}
    }

}

puts "::snit::widgetadaptor sdrblk::ui-tree loaded"
