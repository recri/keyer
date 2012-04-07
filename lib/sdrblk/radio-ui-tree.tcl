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

package provide sdrblk::radio-ui-tree 1.0.0

package require snit
package require Tk

puts "::snit::widgetadaptor sdrblk::radio-ui-tree loaded"

::snit::widgetadaptor sdrblk::radio-ui-tree {
    option -control -readonly yes
    
    method constructor {args} {
	puts "radio-ui-tree constructor $args"
	installhull using ttk::treeview $win -columns {implemented enabled control value} -displaycolumns {implemented enabled control value}
	$self configure {*}$args
	set options(-control) [$options(-partof) cget -control]
	$self update
    }

    method update {} {
	set c $options(-control)
	set modules {}
	foreach module [$c list] {
	    set label $module
	    set columns [list [$c ccget $module -implemented] [$c ccget $module -enabled] {} {}]
	    hull insert [find-parent $modules $module] end -id $label -text $label -values $columns
	    lappend modules $module
	    foreach option [$c controls $module] {
		switch -- $option {
		    default {
			hull insert $module end -values [list {} {} [lindex $option 0] $option]
		    }
		}
	    }
	}
    }
}
