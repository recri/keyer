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
package require sdrtk::vtreeview

snit::widgetadaptor sdrui::tree {
    option -container -readonly yes
    option -control -readonly yes
    
    delegate method * to hull
    delegate option * to hull

    variable data -array {
    }
    
    constructor {args} {
	installhull using sdrtk::vtreeview -columns {value}

	$hull heading #0 -text module/option
	$hull heading #1 -text {option value}
	$hull bind <Button-1> [mymethod pick %W %x %y]
	$hull bind <Button-3> [mymethod inform %W %x %y]
	set data(items) [dict create]
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
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
    proc trim-parent-prefix {parent item} {
	if {[string first $parent- $item] == 0} {
	    return [string range $item [string length $parent-] end]
	} else {
	    return $item
	}
    }
	
    method find-opts {item} { return [$options(-control) part-cget $item -opts] }

    method update {} {
	foreach item [$options(-control) part-list] {
	    set enabled [string is true -strict [$options(-control) part-is-enabled $item]]
	    set activated [string is true -strict [$options(-control) part-is-active $item ]]
	    if { ! [dict exists $data(items) $item]} {
		set parent [find-parent $item $data(items)]
		set name [trim-parent-prefix $parent $item]
		$hull insert $parent end -id $item -text $name -tag $item
		dict set data(items) $item [dict create item $item type [$options(-control) part-type $item] parent $parent name $name]
		foreach oname [$self find-opts $item] {
		    set oitem $item:$oname
		    $hull insert $item end -id $oitem -text $oname -tag $oitem -values [list [$options(-control) part-cget $item $oname]]
		    dict set data(items) $oitem [dict create item $oitem type option parent $item name $oname]
		}
	    }
	    dict set data(items) $item enabled $enabled
	    dict set data(items) $item activated $activated
	    if {$activated} {
		$hull tag configure $item -foreground darkgreen
	    } elseif {$enabled} {
		$hull tag configure $item -foreground black
	    } else {
		$hull tag configure $item -foreground grey
	    }
	}
	set data(update-pending) 0
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
